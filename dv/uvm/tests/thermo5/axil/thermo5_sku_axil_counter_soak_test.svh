// Repeat one independently checked packet without allocating stream-sized
// vectors or UVM transactions. Check every backend input and the PA prefix.
// The backend recurrence stays continuous through all packet boundaries.
class thermo5_sku_axil_counter_soak_test extends uvm_test;
  `uvm_component_utils(thermo5_sku_axil_counter_soak_test)
  localparam int BEATS = 32;
  localparam int WORDS = 56;
  virtual thermo5_sku_if vif;
  virtual thermo5_axil_if axil;
  logic [15:0] source_i[BEATS*14], source_q[BEATS*14], gain[WORDS];
  logic [511:0] expected_backend_i[WORDS], expected_backend_q[WORDS];
  logic [255:0] expected_pa_prefix[WORDS-1];
  longint unsigned frames, beats_sent, backend_words_checked, pa_words_seen;
  int unsigned saturation_per_frame[16];
  int target_bit = 14;
  bit saturation;
  bit reset_done;

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    string vector_dir;
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif) ||
        !uvm_config_db#(virtual thermo5_axil_if)::get(this,"","axil_vif",axil))
      `uvm_fatal("SOAK_INTERFACE","Counter soak requires an AXI-Lite Product Top")
    if (!$value$plusargs("VEC_DIR=%s",vector_dir) ||
        !$value$plusargs("COUNTER_SOAK_FRAMES=%d",frames) ||
        frames<1 || frames>64'd4294967296)
      `uvm_fatal("SOAK_CONFIG","Supply a one-packet vector directory and 1 through 2^32 frames")
    void'($value$plusargs("COUNTER_SOAK_BIT=%d",target_bit));
    if (target_bit<0 || target_bit>31)
      `uvm_fatal("SOAK_CONFIG","Target bit must be in [0,31]")
    saturation=$test$plusargs("COUNTER_SOAK_SATURATION");
    $readmemh({vector_dir,"/tid32_thermo5_frontend_i.mem"},source_i);
    $readmemh({vector_dir,"/tid32_thermo5_frontend_q.mem"},source_q);
    $readmemh({vector_dir,"/tid32_thermo5_frontend_frame_gain.mem"},gain);
    $readmemh({vector_dir,"/backend_i.mem"},expected_backend_i);
    $readmemh({vector_dir,"/backend_q.mem"},expected_backend_q);
    $readmemh({vector_dir,"/pa_prefix.mem"},expected_pa_prefix);
    $readmemh({vector_dir,"/dpd_saturation_per_frame.mem"},saturation_per_frame);
    for (int lane=0;lane<16;lane++)
      if ((saturation && (frames*saturation_per_frame[lane] < (64'd1<<target_bit))) ||
          (!saturation && (frames*(WORDS+1) < (64'd1<<target_bit))))
        `uvm_fatal("SOAK_LENGTH",$sformatf("Frame count cannot reach the target in lane %0d",lane))
  endfunction

  task axil_write(input bit [7:0] address,input bit [31:0] data);
    @(negedge axil.aclk);
    axil.awaddr=address;
    axil.wdata=data;
    axil.awvalid=1;
    axil.wvalid=1;
    axil.bready=1;
    fork
      begin
        do @(posedge axil.aclk); while (axil.awready!==1'b1);
        @(negedge axil.aclk);
        axil.awvalid=0;
      end
      begin
        do @(posedge axil.aclk); while (axil.wready!==1'b1);
        @(negedge axil.aclk);
        axil.wvalid=0;
      end
    join
    do @(posedge axil.aclk); while (axil.bvalid!==1'b1);
    if (axil.bresp!==2'b00)
      `uvm_fatal("SOAK_AXIL",$sformatf("Write %02x rejected with %b",address,axil.bresp))
    @(negedge axil.aclk);
    axil.bready=0;
  endtask

  task send_packets();
    for (longint unsigned frame=0;frame<frames;frame++) begin
      for (int beat=0;beat<BEATS;beat++) begin
        @(negedge vif.src_clk);
        for (int lane=0;lane<14;lane++) begin
          vif.src_i[lane*16+:16]=source_i[14*beat+lane];
          vif.src_q[lane*16+:16]=source_q[14*beat+lane];
        end
        vif.frame_start=(beat==0);
        vif.frame_gain=gain[(14*beat)/8];
        vif.src_last=(beat==BEATS-1);
        vif.src_valid=1;
        do @(posedge vif.src_clk); while (vif.src_ready!==1'b1);
        beats_sent++;
      end
    end
    @(negedge vif.src_clk);
    vif.src_valid=0;
  endtask

  task check_output();
    int word=0;
    forever begin
      @(posedge vif.core_clk);
      if (vif.core_rst_n && !reset_done) begin
        if (vif.protocol_error || (vif.underflow && beats_sent<frames*BEATS))
          `uvm_fatal("SOAK_PROTOCOL",$sformatf("Protocol/underflow at beat %0d",beats_sent))
        if (vif.ef2_input_valid && vif.ef2_input_ready) begin
          if (backend_words_checked==frames*WORDS ||
              vif.ef2_input_i_vec!==expected_backend_i[word] ||
              vif.ef2_input_q_vec!==expected_backend_q[word])
            `uvm_fatal("SOAK_BACKEND_BITTRUE",$sformatf("Backend input mismatch at word %0d",
              backend_words_checked))
          backend_words_checked++;
          word=(word==WORDS-1) ? 0 : word+1;
        end
        if (vif.pa_valid===4'hf) begin
          if (pa_words_seen==frames*WORDS)
            `uvm_fatal("SOAK_EXTRA","Unexpected PA word after the full stream")
          if (pa_words_seen<WORDS-1)
            for (int plane=0;plane<4;plane++)
              if (vif.pa_data[plane]!==expected_pa_prefix[pa_words_seen][64*plane+:64])
                `uvm_fatal("SOAK_PA_BITTRUE",$sformatf("Word %0d plane %0d",
                  pa_words_seen,plane))
          pa_words_seen++;
        end else if (vif.pa_valid!==4'h0)
          `uvm_fatal("SOAK_VALID","PA valid vector disagreed across planes")
      end
    end
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    vif.pa_ready=4'hf;
    repeat (4) @(negedge vif.core_clk);
    vif.core_rst_n=1;
    @(negedge vif.src_clk);
    vif.src_rst_n=1;
    wait(axil.aresetn===1'b1);
    fork
      begin
        fork
          send_packets();
          begin
            if (saturation) begin
              for (int slot=0;slot<6;slot++)
                axil_write(8'h10+8'(8*slot),32'h00007fff);
              axil_write(8'h00,32'h2);
              wait(vif.cfg_pending_valid===1'b1);
            end
            wait(beats_sent>=16);
            axil_write(8'h00,32'h1);
            wait(beats_sent==frames*BEATS);
            axil_write(8'h00,32'h0);
          end
        join
        wait(pa_words_seen==frames*WORDS && vif.core_tx_active===1'b0);
        if (backend_words_checked!=frames*WORDS)
          `uvm_fatal("SOAK_BACKEND_COUNT","Backend input count did not match the stream length")
        if (saturation && vif.cfg_done!==1'b1)
          `uvm_fatal("SOAK_COMMIT","Saturation coefficients did not complete COMMIT")
        @(negedge vif.core_clk);
        for (int lane=0;lane<16;lane++)
          if (vif.dpd_sample_count[lane]!==32'(frames*(WORDS+1)) ||
              vif.dpd_saturation_count[lane]!==32'(frames*saturation_per_frame[lane]))
            `uvm_fatal("SOAK_COUNTER",$sformatf("lane=%0d sample=%0d saturation=%0d",
              lane,vif.dpd_sample_count[lane],vif.dpd_saturation_count[lane]))
        reset_done=1;
        vif.core_rst_n=0;
        vif.src_rst_n=0;
        repeat (3) @(negedge vif.core_clk);
        for (int lane=0;lane<16;lane++)
          if (vif.dpd_sample_count[lane]!==0 || vif.dpd_saturation_count[lane]!==0)
            `uvm_fatal("SOAK_RESET",$sformatf("Lane %0d counters did not clear",lane))
        `uvm_info("SKU_PASS",$sformatf("THERMO5_AXIL_COUNTER_SOAK_PASS frames=%0d words=%0d bit=%0d saturation=%0b",
          frames,backend_words_checked,target_bit,saturation),UVM_NONE)
      end
      check_output();
      begin
        longint unsigned previous_words;
        do begin
          previous_words=pa_words_seen;
          repeat (100000) @(posedge vif.core_clk);
          if (pa_words_seen==previous_words)
            `uvm_fatal("SOAK_TIMEOUT","No verified PA progress within 100000 core clocks")
        end while (1);
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
