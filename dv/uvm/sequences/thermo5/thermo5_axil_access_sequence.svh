class thermo5_axil_access_sequence extends uvm_sequence #(thermo5_axil_item);
  `uvm_object_utils(thermo5_axil_access_sequence)
  bit is_write;
  bit [7:0] addr;
  bit [31:0] data;
  bit [3:0] strb = 4'hf;
  int unsigned aw_delay, w_delay, response_delay;
  bit ready_before_response;
  bit [31:0] rdata;
  bit [1:0] resp;

  function new(string name = "thermo5_axil_access_sequence");
    super.new(name);
  endfunction

  task body();
    thermo5_axil_item req = thermo5_axil_item::type_id::create("req");
    start_item(req);
    req.is_write = is_write;
    req.addr = addr;
    req.data = data;
    req.strb = strb;
    req.aw_delay = aw_delay;
    req.w_delay = w_delay;
    req.response_delay = response_delay;
    req.ready_before_response = ready_before_response;
    finish_item(req);
    rdata = req.rdata;
    resp = req.resp;
  endtask
endclass
