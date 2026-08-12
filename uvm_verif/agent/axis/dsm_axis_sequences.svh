class dsm_axis_single_item_sequence extends uvm_sequence #(dsm_axis_item);
  `uvm_object_utils(dsm_axis_single_item_sequence)
  bit signed [15:0] i_sample;
  bit signed [15:0] q_sample;
  bit last;
  bit user_error;
  int unsigned valid_gap_cycles;

  function new(string name = "dsm_axis_single_item_sequence");
    super.new(name);
  endfunction

  task body();
    dsm_axis_item req;
    req = dsm_axis_item::type_id::create("req");
    start_item(req);
    req.i_sample = i_sample;
    req.q_sample = q_sample;
    req.last = last;
    req.user_error = user_error;
    req.valid_gap_cycles = valid_gap_cycles;
    finish_item(req);
  endtask
endclass

class dsm_axis_random_burst_sequence extends uvm_sequence #(dsm_axis_item);
  `uvm_object_utils(dsm_axis_random_burst_sequence)
  int unsigned item_count = 64;
  int unsigned max_valid_gap = 3;
  int unsigned first_valid_gap = 0;
  int signed amplitude = 8192;

  function new(string name = "dsm_axis_random_burst_sequence");
    super.new(name);
  endfunction

  task body();
    dsm_axis_item req;
    int signed span;
    span = (amplitude > 0) ? amplitude : 1;
    for (int unsigned n = 0; n < item_count; n++) begin
      req = dsm_axis_item::type_id::create($sformatf("req_%0d", n));
      start_item(req);
      req.i_sample = $signed($urandom_range(0, 2 * span)) - span;
      req.q_sample = $signed($urandom_range(0, 2 * span)) - span;
      req.last = (n == item_count - 1);
      req.user_error = 0;
      req.valid_gap_cycles = (n == 0) ? first_valid_gap :
                             $urandom_range(0, max_valid_gap);
      finish_item(req);
    end
  endtask
endclass

class dsm_axis_csv_sequence extends uvm_sequence #(dsm_axis_item);
  `uvm_object_utils(dsm_axis_csv_sequence)
  string vector_set = "performance_sku";
  string csv_path = "";

  function new(string name = "dsm_axis_csv_sequence");
    super.new(name);
  endfunction

  task body();
    integer fd;
    integer code;
    integer sample_index;
    integer i_value;
    integer q_value;
    integer last_value;
    string header;
    dsm_axis_item req;
    if (csv_path == "")
      csv_path = $sformatf("%s/%s_input.csv", dsm_vector_dir(), vector_set);
    fd = $fopen(csv_path, "r");
    if (fd == 0)
      `uvm_fatal("VECTOR_OPEN", $sformatf("Cannot open %s", csv_path))
    void'($fgets(header, fd));
    while (!$feof(fd)) begin
      code = $fscanf(fd, "%d,%d,%d,%d\n", sample_index, i_value, q_value, last_value);
      if (code == 4) begin
        req = dsm_axis_item::type_id::create($sformatf("csv_%0d", sample_index));
        start_item(req);
        req.i_sample = i_value;
        req.q_sample = q_value;
        req.last = last_value[0];
        req.user_error = 1'b0;
        req.valid_gap_cycles = 0;
        finish_item(req);
      end else if (code != -1) begin
        `uvm_fatal("VECTOR_PARSE", $sformatf("Malformed row in %s", csv_path))
      end
    end
    $fclose(fd);
  endtask
endclass
