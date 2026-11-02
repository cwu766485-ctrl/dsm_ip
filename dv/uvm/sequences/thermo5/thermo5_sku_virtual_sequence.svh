// Small cross-agent product sequence: request RUN, stream one complete packet,
// request STOP, then check drain completion through independent agent monitors.
class thermo5_sku_axil_packet_vseq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(thermo5_sku_axil_packet_vseq)
  `uvm_declare_p_sequencer(thermo5_sku_virtual_sequencer)

  function new(string name="thermo5_sku_axil_packet_vseq");
    super.new(name);
  endfunction

  task automatic axil_write(input bit [7:0] addr,
                            input bit [31:0] data,
                            output bit [1:0] resp);
    thermo5_axil_access_sequence access;
    access=thermo5_axil_access_sequence::type_id::create("vseq_axil_write");
    access.is_write=1;
    access.addr=addr;
    access.data=data;
    access.strb=4'hf;
    access.aw_delay=0;
    access.w_delay=0;
    access.response_delay=1;
    access.ready_before_response=0;
    access.start(p_sequencer.axil_sequencer);
    resp=access.resp;
  endtask

  task automatic axil_read(input bit [7:0] addr,
                           output bit [31:0] data,
                           output bit [1:0] resp);
    thermo5_axil_access_sequence access;
    access=thermo5_axil_access_sequence::type_id::create("vseq_axil_read");
    access.is_write=0;
    access.addr=addr;
    access.data='0;
    access.strb=4'hf;
    access.aw_delay=0;
    access.w_delay=0;
    access.response_delay=0;
    access.ready_before_response=0;
    access.start(p_sequencer.axil_sequencer);
    data=access.rdata;
    resp=access.resp;
  endtask

  task body();
    thermo5_source_sequence source_seq;
    bit [1:0] resp;
    bit [31:0] status;
    bit drained;
    if (p_sequencer.cfg==null || p_sequencer.source_sequencer==null ||
        p_sequencer.axil_sequencer==null || p_sequencer.pa_monitor==null)
      `uvm_fatal("VSEQ_CONFIG","Thermo5 packet virtual sequencer handles are incomplete")

    axil_write(8'h00,32'h1,resp);
    if (resp!=2'b00)
      `uvm_fatal("VSEQ_RUN","Virtual-sequence RUN request failed")

    source_seq=thermo5_source_sequence::type_id::create("vseq_source_packet");
    source_seq.cfg=p_sequencer.cfg;
    source_seq.beat_count=p_sequencer.cfg.source_beats;
    source_seq.mark_last=1;
    source_seq.packet_beats=p_sequencer.cfg.source_beats;
    source_seq.start(p_sequencer.source_sequencer);

    axil_write(8'h00,32'h0,resp);
    if (resp!=2'b00)
      `uvm_fatal("VSEQ_STOP","Virtual-sequence STOP request failed")
    for (int cycle=0;cycle<20000 &&
         p_sequencer.pa_monitor.accepted_words<p_sequencer.cfg.core_words;cycle++)
      @(posedge p_sequencer.pa_monitor.vif.core_clk);
    if (p_sequencer.pa_monitor.accepted_words!=p_sequencer.cfg.core_words)
      `uvm_fatal("VSEQ_DRAIN_TIMEOUT","PA sink did not accept the complete packet")

    drained=0;
    for (int poll=0;poll<100 && !drained;poll++) begin
      axil_read(8'h04,status,resp);
      if (resp!=2'b00)
        `uvm_fatal("VSEQ_STATUS_READ","Virtual-sequence STATUS read failed")
      drained=(status[4:3]==2'b00);
    end
    if (!drained)
      `uvm_fatal("VSEQ_STATUS",
        $sformatf("Expected drained idle STATUS after packet, resp=%b status=%08x",resp,status))
  endtask
endclass
