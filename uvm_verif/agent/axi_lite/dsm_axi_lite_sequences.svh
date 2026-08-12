class dsm_axi_lite_write_sequence extends uvm_sequence #(dsm_axi_lite_item);
  `uvm_object_utils(dsm_axi_lite_write_sequence)
  dsm_reg_addr_t addr;
  bit [31:0] data;
  int unsigned addr_delay_cycles;
  int unsigned data_delay_cycles;
  int unsigned ready_delay_cycles;
  bit [1:0] resp;

  function new(string name = "dsm_axi_lite_write_sequence");
    super.new(name);
  endfunction

  task body();
    dsm_axi_lite_item req;
    req = dsm_axi_lite_item::type_id::create("req");
    start_item(req);
    req.is_write = 1;
    req.addr = addr;
    req.data = data;
    req.addr_delay_cycles = addr_delay_cycles;
    req.data_delay_cycles = data_delay_cycles;
    req.ready_delay_cycles = ready_delay_cycles;
    finish_item(req);
    resp = req.resp;
  endtask
endclass

class dsm_axi_lite_read_sequence extends uvm_sequence #(dsm_axi_lite_item);
  `uvm_object_utils(dsm_axi_lite_read_sequence)
  dsm_reg_addr_t addr;
  int unsigned addr_delay_cycles;
  int unsigned ready_delay_cycles;
  bit [31:0] rdata;
  bit [1:0] resp;

  function new(string name = "dsm_axi_lite_read_sequence");
    super.new(name);
  endfunction

  task body();
    dsm_axi_lite_item req;
    req = dsm_axi_lite_item::type_id::create("req");
    start_item(req);
    req.is_write = 0;
    req.addr = addr;
    req.addr_delay_cycles = addr_delay_cycles;
    req.data_delay_cycles = 0;
    req.ready_delay_cycles = ready_delay_cycles;
    finish_item(req);
    rdata = req.rdata;
    resp = req.resp;
  endtask
endclass
