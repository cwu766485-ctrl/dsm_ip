// Exact II=1 map composition using transaction-ID context and result banks.
//
// Each accepted map is written once to a synchronous context RAM.  Every
// compose slot moves only a narrow {valid, id, cursor} token plus selected
// metadata; its map read response is captured as an explicit stage record.
// Fixed result slots are written to RAM and synchronously read only after the
// final slot completes.  This prevents wide-map forwarding and avoids turning
// a context-bank read into a large combinational address mux.
`timescale 1ns/1ps
`default_nettype none

module bp_ef2_map_compose_id_pipe #(
  parameter int ACC_W = 28, parameter int L_REGIONS = 5,
  parameter int R_REGIONS = 5, parameter int OUT_REGIONS = 9,
  parameter int L_BITS = 4, parameter int R_BITS = 4,
  // The default covers the 4-stage-per-slot compose8 implementation. Larger
  // compose trees must supply a depth exceeding their in-flight latency.
  parameter int CTX_DEPTH = 64,
  parameter bit USE_CONTEXT_BANK = 1'b0
) (
  input wire logic clk, rst_n, in_valid,
  input wire logic [L_REGIONS-1:0] l_valid, l_slope_neg,
  input wire logic signed [L_REGIONS*ACC_W-1:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [L_REGIONS*L_BITS-1:0] l_bits_bus,
  input wire logic [R_REGIONS-1:0] r_valid, r_slope_neg,
  input wire logic signed [R_REGIONS*ACC_W-1:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [R_REGIONS*R_BITS-1:0] r_bits_bus,
  output logic out_valid,
  output logic [OUT_REGIONS-1:0] out_map_valid, out_slope_neg,
  output logic signed [OUT_REGIONS*ACC_W-1:0] out_lo_bus, out_hi_bus, out_offset_bus,
  output logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] out_bits_bus
);
  generate if (!USE_CONTEXT_BANK) begin : gen_reference_pipe
    bp_ef2_map_compose_pipe #(.ACC_W(ACC_W),.L_REGIONS(L_REGIONS),.R_REGIONS(R_REGIONS),.OUT_REGIONS(OUT_REGIONS),.L_BITS(L_BITS),.R_BITS(R_BITS)) u_ref_pipe (
      .clk(clk),.rst_n(rst_n),.in_valid(in_valid),
      .l_valid(l_valid),.l_slope_neg(l_slope_neg),.l_lo_bus(l_lo_bus),.l_hi_bus(l_hi_bus),.l_offset_bus(l_offset_bus),.l_bits_bus(l_bits_bus),
      .r_valid(r_valid),.r_slope_neg(r_slope_neg),.r_lo_bus(r_lo_bus),.r_hi_bus(r_hi_bus),.r_offset_bus(r_offset_bus),.r_bits_bus(r_bits_bus),
      .out_valid(out_valid),.out_map_valid(out_map_valid),.out_slope_neg(out_slope_neg),.out_lo_bus(out_lo_bus),.out_hi_bus(out_hi_bus),.out_offset_bus(out_offset_bus),.out_bits_bus(out_bits_bus));
  end else begin : gen_context_pipe
    localparam int ID_W = $clog2(CTX_DEPTH);
    localparam int L_CTX_W = 2*L_REGIONS + 3*L_REGIONS*ACC_W + L_REGIONS*L_BITS;
    localparam int R_CTX_W = 2*R_REGIONS + 3*R_REGIONS*ACC_W + R_REGIONS*R_BITS;
    localparam int CTX_W = L_CTX_W + R_CTX_W;
    localparam int SLOT_W = 2 + 3*ACC_W + L_BITS + R_BITS;
    localparam logic signed [ACC_W-1:0] DOMAIN_MIN = -32769;
    localparam logic signed [ACC_W-1:0] DOMAIN_MAX = 32769;

    logic [ID_W-1:0] write_id, ingress_id;
    logic ingress_valid;
    logic [CTX_W-1:0] context_mem [0:CTX_DEPTH-1];
    logic [SLOT_W-1:0] result_mem [0:OUT_REGIONS-1][0:CTX_DEPTH-1];

    logic vc [0:OUT_REGIONS-1], vl [0:OUT_REGIONS-1], vr [0:OUT_REGIONS-1], ve [0:OUT_REGIONS-1];
    logic [ID_W-1:0] idc [0:OUT_REGIONS-1], idl [0:OUT_REGIONS-1], idr [0:OUT_REGIONS-1], ide [0:OUT_REGIONS-1];
    logic signed [ACC_W-1:0] cc [0:OUT_REGIONS-1], cl [0:OUT_REGIONS-1], cr [0:OUT_REGIONS-1], ce [0:OUT_REGIONS-1];
    logic [CTX_W-1:0] context_c [0:OUT_REGIONS-1];
    logic [R_REGIONS-1:0] rv_l [0:OUT_REGIONS-1], rs_l [0:OUT_REGIONS-1];
    logic signed [R_REGIONS*ACC_W-1:0] rlo_l [0:OUT_REGIONS-1], rhi_l [0:OUT_REGIONS-1], rof_l [0:OUT_REGIONS-1];
    logic [R_REGIONS*R_BITS-1:0] rb_l [0:OUT_REGIONS-1];
    logic lf [0:OUT_REGIONS-1], lsn [0:OUT_REGIONS-1], rf [0:OUT_REGIONS-1], rsn [0:OUT_REGIONS-1];
    logic lfr [0:OUT_REGIONS-1], lsnr [0:OUT_REGIONS-1];
    logic signed [ACC_W-1:0] lhi [0:OUT_REGIONS-1], lof [0:OUT_REGIONS-1];
    logic signed [ACC_W-1:0] lhir [0:OUT_REGIONS-1], lofr [0:OUT_REGIONS-1];
    logic signed [ACC_W-1:0] rlo [0:OUT_REGIONS-1], rhi [0:OUT_REGIONS-1], rof [0:OUT_REGIONS-1];
    logic [L_BITS-1:0] lb [0:OUT_REGIONS-1], lbr [0:OUT_REGIONS-1];
    logic [R_BITS-1:0] rb [0:OUT_REGIONS-1];
    logic completion_valid, out_valid_q;
    logic [ID_W-1:0] completion_id;
    logic [SLOT_W-1:0] output_slot_q [0:OUT_REGIONS-1];

    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        write_id <= '0;
        ingress_valid <= 1'b0;
        ingress_id <= '0;
      end else begin
        ingress_valid <= in_valid;
        ingress_id <= write_id;
        if (in_valid) begin
          // CTX_DEPTH is selected for the stage latency and need not be a
          // power of two.  Never address a context outside the allocated
          // bank when the transaction counter wraps.
          if (write_id == CTX_DEPTH-1) write_id <= '0;
          else write_id <= write_id + 1'b1;
        end
      end
    end
    // Keep the context RAM out of the reset-bearing control process.  This is
    // the canonical synchronous single-write-port RAM pattern for Vivado.
    always_ff @(posedge clk) begin
      if (in_valid)
        context_mem[write_id] <= {r_bits_bus, r_offset_bus, r_hi_bus, r_lo_bus, r_slope_neg, r_valid,
                                  l_bits_bus, l_offset_bus, l_hi_bus, l_lo_bus, l_slope_neg, l_valid};
    end

    genvar g;
    for (g = 0; g < OUT_REGIONS; g = g + 1) begin : gen_slot
      wire token_in = (g == 0) ? ingress_valid : ve[g-1];
      wire [ID_W-1:0] id_in = (g == 0) ? ingress_id : ide[g-1];
      wire logic signed [ACC_W-1:0] cursor_in = (g == 0) ? DOMAIN_MIN : ce[g-1];
      wire [L_REGIONS-1:0] lv_c = context_c[g][0 +: L_REGIONS];
      wire [L_REGIONS-1:0] ls_c = context_c[g][L_REGIONS +: L_REGIONS];
      wire logic signed [L_REGIONS*ACC_W-1:0] llo_c = context_c[g][2*L_REGIONS +: L_REGIONS*ACC_W];
      wire logic signed [L_REGIONS*ACC_W-1:0] lhi_c = context_c[g][2*L_REGIONS + L_REGIONS*ACC_W +: L_REGIONS*ACC_W];
      wire logic signed [L_REGIONS*ACC_W-1:0] lof_c = context_c[g][2*L_REGIONS + 2*L_REGIONS*ACC_W +: L_REGIONS*ACC_W];
      wire [L_REGIONS*L_BITS-1:0] lb_c = context_c[g][2*L_REGIONS + 3*L_REGIONS*ACC_W +: L_REGIONS*L_BITS];
      wire [R_REGIONS-1:0] rv_c = context_c[g][L_CTX_W +: R_REGIONS];
      wire [R_REGIONS-1:0] rs_c = context_c[g][L_CTX_W + R_REGIONS +: R_REGIONS];
      wire logic signed [R_REGIONS*ACC_W-1:0] rlo_c = context_c[g][L_CTX_W + 2*R_REGIONS +: R_REGIONS*ACC_W];
      wire logic signed [R_REGIONS*ACC_W-1:0] rhi_c = context_c[g][L_CTX_W + 2*R_REGIONS + R_REGIONS*ACC_W +: R_REGIONS*ACC_W];
      wire logic signed [R_REGIONS*ACC_W-1:0] rof_c = context_c[g][L_CTX_W + 2*R_REGIONS + 2*R_REGIONS*ACC_W +: R_REGIONS*ACC_W];
      wire [R_REGIONS*R_BITS-1:0] rb_c = context_c[g][L_CTX_W + 2*R_REGIONS + 3*R_REGIONS*ACC_W +: R_REGIONS*R_BITS];
      logic lfc, lsc, rfc, rsc;
      logic signed [ACC_W-1:0] lloc, lhic, lofc, rloc, rhic, rofc;
      logic [L_BITS-1:0] lbc;
      logic [R_BITS-1:0] rbc;
      logic signed [ACC_W-1:0] left_state, next_cursor;
      logic signed [ACC_W:0] pre_hi, int_hi, off_val;
      logic emit;
      logic [SLOT_W-1:0] result_c;

      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) vc[g] <= 1'b0;
        else vc[g] <= token_in;
      end
      always_ff @(posedge clk) begin
        idc[g] <= id_in;
        cc[g] <= cursor_in;
        if (token_in) context_c[g] <= context_mem[id_in];
      end

      bp_ef2_map_region_select #(.ACC_W(ACC_W),.REGIONS(L_REGIONS),.BITS_W(L_BITS)) u_left (
        .state_in(cc[g]),.region_valid(lv_c),.region_slope_neg(ls_c),.region_lo_bus(llo_c),.region_hi_bus(lhi_c),.region_offset_bus(lof_c),.region_bits_bus(lb_c),
        .found(lfc),.slope_neg_out(lsc),.lo_out(lloc),.hi_out(lhic),.offset_out(lofc),.bits_out(lbc));
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) vl[g] <= 1'b0;
        else vl[g] <= vc[g];
      end
      always_ff @(posedge clk) begin
        idl[g] <= idc[g]; cl[g] <= cc[g];
        lf[g] <= lfc; lsn[g] <= lsc; lhi[g] <= lhic; lof[g] <= lofc; lb[g] <= lbc;
        rv_l[g] <= rv_c; rs_l[g] <= rs_c; rlo_l[g] <= rlo_c; rhi_l[g] <= rhi_c; rof_l[g] <= rof_c; rb_l[g] <= rb_c;
      end

      always_comb left_state = lsn[g] ? (-$signed(cl[g]) + $signed(lof[g])) : ($signed(cl[g]) + $signed(lof[g]));
      bp_ef2_map_region_select #(.ACC_W(ACC_W),.REGIONS(R_REGIONS),.BITS_W(R_BITS)) u_right (
        .state_in(left_state),.region_valid(rv_l[g]),.region_slope_neg(rs_l[g]),.region_lo_bus(rlo_l[g]),.region_hi_bus(rhi_l[g]),.region_offset_bus(rof_l[g]),.region_bits_bus(rb_l[g]),
        .found(rfc),.slope_neg_out(rsc),.lo_out(rloc),.hi_out(rhic),.offset_out(rofc),.bits_out(rbc));
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) vr[g] <= 1'b0;
        else vr[g] <= vl[g];
      end
      always_ff @(posedge clk) begin
        idr[g] <= idl[g]; cr[g] <= cl[g];
        lfr[g] <= lf[g]; lsnr[g] <= lsn[g]; lhir[g] <= lhi[g]; lofr[g] <= lof[g]; lbr[g] <= lb[g];
        rf[g] <= rfc; rsn[g] <= rsc; rlo[g] <= rloc; rhi[g] <= rhic; rof[g] <= rofc; rb[g] <= rbc;
      end

      always_comb begin
        pre_hi = lsnr[g] ? ($signed(lofr[g]) - $signed(rlo[g])) : ($signed(rhi[g]) - $signed(lofr[g]));
        int_hi = ($signed(lhir[g]) < $signed(pre_hi)) ? $signed(lhir[g]) : pre_hi;
        off_val = rsn[g] ? (-$signed(lofr[g]) + $signed(rof[g])) : ($signed(lofr[g]) + $signed(rof[g]));
        emit = lfr[g] && rf[g] && ($signed(cr[g]) <= $signed(DOMAIN_MAX)) && ($signed(int_hi) >= $signed(cr[g]));
        next_cursor = emit ? int_hi[ACC_W-1:0] + 1'b1 : DOMAIN_MAX + 1'b1;
        result_c = {emit, (lsnr[g] ^ rsn[g]), cr[g], int_hi[ACC_W-1:0], off_val[ACC_W-1:0], rb[g], lbr[g]};
      end
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) ve[g] <= 1'b0;
        else ve[g] <= vr[g];
      end
      always_ff @(posedge clk) begin
        ide[g] <= idr[g];
        ce[g] <= next_cursor;
        if (vr[g]) result_mem[g][idr[g]] <= result_c;
      end
    end

    // One fixed read port per result slot gives Vivado independent simple
    // dual-port memories rather than one unsupported 3-D RAM expression.
    genvar h;
    for (h = 0; h < OUT_REGIONS; h = h + 1) begin : gen_result_read
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) output_slot_q[h] <= '0;
        else if (completion_valid) output_slot_q[h] <= result_mem[h][completion_id];
      end
      assign out_map_valid[h] = output_slot_q[h][SLOT_W-1];
      assign out_slope_neg[h] = output_slot_q[h][SLOT_W-2];
      assign out_lo_bus[h*ACC_W +: ACC_W] = output_slot_q[h][SLOT_W-3 -: ACC_W];
      assign out_hi_bus[h*ACC_W +: ACC_W] = output_slot_q[h][SLOT_W-3-ACC_W -: ACC_W];
      assign out_offset_bus[h*ACC_W +: ACC_W] = output_slot_q[h][SLOT_W-3-2*ACC_W -: ACC_W];
      assign out_bits_bus[h*(L_BITS+R_BITS) +: (L_BITS+R_BITS)] = output_slot_q[h][L_BITS+R_BITS-1:0];
    end

    // A final emit creates a completion token. The following edge performs
    // the synchronous per-slot result reads, so data is stable with out_valid.
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        completion_valid <= 1'b0;
        completion_id <= '0;
        out_valid_q <= 1'b0;
      end else begin
        completion_valid <= ve[OUT_REGIONS-1];
        completion_id <= ide[OUT_REGIONS-1];
        out_valid_q <= completion_valid;
      end
    end
    assign out_valid = out_valid_q;
  end endgenerate
endmodule
`default_nettype wire
