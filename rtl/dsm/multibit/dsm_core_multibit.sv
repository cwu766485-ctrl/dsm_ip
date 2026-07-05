`timescale 1ns/1ps
`default_nettype none

// Exploratory Cartesian multibit DSM core.
//
// MB_ALGORITHM:
//   0 LPDSM, 1 LPDSM2, 2 EFDSM, 3 EFDSM2, 4 MASH11, 5 MASH111, 6 MASH22
//
// This RTL mirrors the MATLAB exploration model in
// matlab/cartesian_dsm/dsm_multibit/dsm_multibit_model.m. It is intended as a
// pre-signoff RTL implementation; keep MATLAB/RTL bit-true checks separate
// from the already signed-off single-bit P0 flow.
module dsm_core_multibit #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter int OUT_W = 8,
  parameter int Q_BITS = 4,
  parameter int MB_ALGORITHM = 0,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b1,
  parameter int COEFF_W = 8,
  parameter int signed B1_NUM = 2,
  parameter int signed B2_NUM = -1,
  parameter int COEFF_SHIFT = 0
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic enable,
  input  wire logic signed [W_IN-1:0] x_in,
  output logic y_bit,
  output logic signed [OUT_W-1:0] y_code,
  output logic signed [ACC_W-1:0] v1_state,
  output logic signed [ACC_W-1:0] v2_state
);

  localparam int SUM_W = ACC_W + COEFF_W + 4;
  localparam int QMAX = (1 << (Q_BITS - 1)) - 1;
  localparam int FS = (1 << (W_IN - 1)) - 1;
  localparam int HALF_FS = FS / 2;
  localparam logic signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam logic signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};
  localparam logic signed [COEFF_W-1:0] B1_Q = B1_NUM;
  localparam logic signed [COEFF_W-1:0] B2_Q = B2_NUM;

  logic signed [ACC_W-1:0] s1;
  logic signed [ACC_W-1:0] s2;
  logic signed [ACC_W-1:0] s3;
  logic signed [ACC_W-1:0] s4;
  logic signed [ACC_W-1:0] e1_reg;
  logic signed [ACC_W-1:0] e2_reg;
  logic signed [OUT_W-1:0] y_reg;
  logic signed [OUT_W-1:0] y1_reg1;
  logic signed [OUT_W-1:0] y1_reg2;
  logic signed [OUT_W-1:0] y2_reg;
  logic signed [OUT_W-1:0] y2_prev1;
  logic signed [OUT_W-1:0] y2_prev2;
  logic signed [OUT_W-1:0] y3_prev1;
  logic signed [OUT_W-1:0] y3_prev2;

  logic signed [W_IN-1:0] x_shifted;
  logic signed [ACC_W-1:0] x_ext;

  logic signed [ACC_W-1:0] q_fb;
  logic signed [ACC_W-1:0] q1_fb;
  logic signed [ACC_W-1:0] q2_fb;
  logic signed [ACC_W-1:0] q3_fb;
  logic signed [OUT_W-1:0] q_code;
  logic signed [OUT_W-1:0] q1_code;
  logic signed [OUT_W-1:0] q2_code;
  logic signed [OUT_W-1:0] q3_code;

  logic signed [ACC_W-1:0] y0;
  logic signed [ACC_W-1:0] y1;
  logic signed [ACC_W-1:0] y2;
  logic signed [ACC_W-1:0] y3;
  logic signed [ACC_W-1:0] n1;
  logic signed [ACC_W-1:0] n2;
  logic signed [ACC_W-1:0] n3;
  logic signed [ACC_W-1:0] n4;
  logic signed [ACC_W-1:0] e0;
  logic signed [ACC_W-1:0] e20;
  logic signed [ACC_W-1:0] b1_s1;
  logic signed [ACC_W-1:0] b2_s2;
  logic signed [ACC_W-1:0] b1_s3;
  logic signed [ACC_W-1:0] b2_s4;
  logic signed [OUT_W-1:0] y_out_c;
  logic signed [OUT_W-1:0] y_next;

  function automatic logic signed [ACC_W-1:0] sat_or_wrap(
    input logic signed [SUM_W-1:0] vin
  );
    begin
      if (SATURATE) begin
        if (vin > $signed({{(SUM_W-ACC_W){V_MAX[ACC_W-1]}}, V_MAX})) begin
          sat_or_wrap = V_MAX;
        end else if (vin < $signed({{(SUM_W-ACC_W){V_MIN[ACC_W-1]}}, V_MIN})) begin
          sat_or_wrap = V_MIN;
        end else begin
          sat_or_wrap = vin[ACC_W-1:0];
        end
      end else begin
        sat_or_wrap = vin[ACC_W-1:0];
      end
    end
  endfunction

  function automatic logic signed [OUT_W-1:0] quant_code(
    input logic signed [ACC_W-1:0] vin
  );
    logic signed [OUT_W-1:0] raw;
    logic signed [OUT_W-1:0] qmax_code;
    begin
      raw = '0;
      for (int c = 1; c <= QMAX; c = c + 1) begin
        if (vin >= pos_input_threshold(c)) begin
          raw = c[OUT_W-1:0];
        end
        if (vin <= neg_input_threshold(c)) begin
          raw = -c[OUT_W-1:0];
        end
      end

      qmax_code = QMAX;
      if (raw > qmax_code) begin
        quant_code = qmax_code;
      end else if (raw < -qmax_code) begin
        quant_code = -qmax_code;
      end else begin
        quant_code = raw;
      end
    end
  endfunction

  function automatic logic signed [ACC_W-1:0] pos_input_threshold(
    input int c
  );
    int numerator;
    begin
      numerator = (c * FS) - HALF_FS;
      pos_input_threshold = (numerator + QMAX - 1) / QMAX;
    end
  endfunction

  function automatic logic signed [ACC_W-1:0] neg_input_threshold(
    input int c
  );
    int numerator;
    begin
      numerator = (-c * FS) + HALF_FS;
      neg_input_threshold = -(((-numerator) + QMAX - 1) / QMAX);
    end
  endfunction

  function automatic logic signed [ACC_W-1:0] feedback_from_code(
    input logic signed [OUT_W-1:0] code
  );
    logic signed [SUM_W-1:0] prod;
    logic signed [ACC_W-1:0] fb;
    begin
      fb = '0;
      for (int c = -QMAX; c <= QMAX; c = c + 1) begin
        if (code == c[OUT_W-1:0]) begin
          prod = c * FS;
          fb = $signed(prod / QMAX);
        end
      end
      feedback_from_code = fb;
    end
  endfunction

  function automatic logic signed [ACC_W-1:0] coeff_term(
    input logic signed [ACC_W-1:0] err,
    input logic signed [COEFF_W-1:0] coeff
  );
    logic signed [SUM_W-1:0] prod;
    logic signed [SUM_W-1:0] rounded;
    begin
      if ((COEFF_SHIFT == 0) && (coeff == 0)) begin
        coeff_term = '0;
      end else if ((COEFF_SHIFT == 0) && (coeff == 1)) begin
        coeff_term = err;
      end else if ((COEFF_SHIFT == 0) && (coeff == -1)) begin
        coeff_term = -err;
      end else if ((COEFF_SHIFT == 0) && (coeff == 2)) begin
        coeff_term = err <<< 1;
      end else if ((COEFF_SHIFT == 0) && (coeff == -2)) begin
        coeff_term = -(err <<< 1);
      end else begin
        prod = $signed(err) * $signed(coeff);
        if (COEFF_SHIFT > 0) begin
          if (prod >= 0) begin
            rounded = prod + (1 <<< (COEFF_SHIFT - 1));
          end else begin
            rounded = prod - (1 <<< (COEFF_SHIFT - 1));
          end
          coeff_term = $signed(rounded >>> COEFF_SHIFT);
        end else begin
          coeff_term = prod[ACC_W-1:0];
        end
      end
    end
  endfunction

  always_comb begin
    x_shifted = (IN_SHIFT == 0) ? x_in : (x_in >>> IN_SHIFT);
    x_ext = {{(ACC_W-W_IN){x_shifted[W_IN-1]}}, x_shifted};

    q_code = (MB_ALGORITHM == 1) ? quant_code(s2) : quant_code(s1);
    q_fb = feedback_from_code(q_code);
    b1_s1 = coeff_term(s1, B1_Q);
    b2_s2 = coeff_term(s2, B2_Q);
    b1_s3 = coeff_term(s3, B1_Q);
    b2_s4 = coeff_term(s4, B2_Q);

    y0 = '0;
    y1 = '0;
    y2 = '0;
    y3 = '0;
    n1 = s1;
    n2 = s2;
    n3 = s3;
    n4 = s4;
    e0 = '0;
    e20 = '0;
    y_out_c = y_reg;
    y_next = y_reg;
    q1_code = '0;
    q2_code = '0;
    q3_code = '0;
    q1_fb = '0;
    q2_fb = '0;
    q3_fb = '0;

    unique case (MB_ALGORITHM)
      0: begin
        y_out_c = y_reg;
        y_next = q_code;
        n1 = sat_or_wrap($signed({{(SUM_W-ACC_W){s1[ACC_W-1]}}, s1}) +
                         $signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) -
                         $signed({{(SUM_W-ACC_W){q_fb[ACC_W-1]}}, q_fb}));
      end

      1: begin
        y_out_c = y_reg;
        y_next = q_code;
        n1 = sat_or_wrap($signed({{(SUM_W-ACC_W){s1[ACC_W-1]}}, s1}) +
                         $signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) -
                         $signed({{(SUM_W-ACC_W){q_fb[ACC_W-1]}}, q_fb}));
        n2 = sat_or_wrap($signed({{(SUM_W-ACC_W){s2[ACC_W-1]}}, s2}) +
                         $signed({{(SUM_W-ACC_W){n1[ACC_W-1]}}, n1}) -
                         $signed({{(SUM_W-ACC_W){q_fb[ACC_W-1]}}, q_fb}));
      end

      2: begin
        y1 = sat_or_wrap($signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) +
                         $signed({{(SUM_W-ACC_W){s1[ACC_W-1]}}, s1}));
        q1_code = quant_code(y1);
        q1_fb = feedback_from_code(q1_code);
        n1 = y1 - q1_fb;
        y_out_c = y_reg;
        y_next = q1_code;
      end

      3: begin
        y1 = sat_or_wrap($signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) +
                         $signed({{(SUM_W-ACC_W){b1_s1[ACC_W-1]}}, b1_s1}) +
                         $signed({{(SUM_W-ACC_W){b2_s2[ACC_W-1]}}, b2_s2}));
        q1_code = quant_code(y1);
        q1_fb = feedback_from_code(q1_code);
        e0 = y1 - q1_fb;
        n2 = s1;
        n1 = e0;
        y_out_c = y_reg;
        y_next = q1_code;
      end

      4: begin
        y1 = sat_or_wrap($signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) +
                         $signed({{(SUM_W-ACC_W){s1[ACC_W-1]}}, s1}));
        q1_code = quant_code(y1);
        q1_fb = feedback_from_code(q1_code);
        e0 = y1 - q1_fb;

        y2 = sat_or_wrap($signed({{(SUM_W-ACC_W){e1_reg[ACC_W-1]}}, e1_reg}) +
                         $signed({{(SUM_W-ACC_W){s2[ACC_W-1]}}, s2}));
        q2_code = quant_code(y2);
        q2_fb = feedback_from_code(q2_code);
        e20 = y2 - q2_fb;

        y_out_c = y_reg;
        y_next = y1_reg1 + (q2_code - y2_prev1);
        n1 = e0;
        n2 = e20;
      end

      5: begin
        y1 = sat_or_wrap($signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) +
                         $signed({{(SUM_W-ACC_W){s1[ACC_W-1]}}, s1}));
        q1_code = quant_code(y1);
        q1_fb = feedback_from_code(q1_code);
        e0 = y1 - q1_fb;

        y2 = sat_or_wrap($signed({{(SUM_W-ACC_W){e1_reg[ACC_W-1]}}, e1_reg}) +
                         $signed({{(SUM_W-ACC_W){s2[ACC_W-1]}}, s2}));
        q2_code = quant_code(y2);
        q2_fb = feedback_from_code(q2_code);
        e20 = y2 - q2_fb;

        y3 = sat_or_wrap($signed({{(SUM_W-ACC_W){e2_reg[ACC_W-1]}}, e2_reg}) +
                         $signed({{(SUM_W-ACC_W){s3[ACC_W-1]}}, s3}));
        q3_code = quant_code(y3);
        q3_fb = feedback_from_code(q3_code);

        y_out_c = y_reg;
        y_next = y1_reg2 + (y2_reg - y2_prev1) + (q3_code - (y3_prev1 <<< 1) + y3_prev2);
        n1 = e0;
        n2 = e20;
        n3 = y3 - q3_fb;
      end

      default: begin
        y1 = sat_or_wrap($signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) +
                         $signed({{(SUM_W-ACC_W){b1_s1[ACC_W-1]}}, b1_s1}) +
                         $signed({{(SUM_W-ACC_W){b2_s2[ACC_W-1]}}, b2_s2}));
        q1_code = quant_code(y1);
        q1_fb = feedback_from_code(q1_code);
        e0 = y1 - q1_fb;

        y2 = sat_or_wrap($signed({{(SUM_W-ACC_W){e1_reg[ACC_W-1]}}, e1_reg}) +
                         $signed({{(SUM_W-ACC_W){b1_s3[ACC_W-1]}}, b1_s3}) +
                         $signed({{(SUM_W-ACC_W){b2_s4[ACC_W-1]}}, b2_s4}));
        q2_code = quant_code(y2);
        q2_fb = feedback_from_code(q2_code);
        e20 = y2 - q2_fb;

        y_out_c = y_reg;
        y_next = y1_reg1 + q2_code - (y2_prev1 <<< 1) + y2_prev2;
        n2 = s1;
        n1 = e0;
        n4 = s3;
        n3 = e20;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1 <= '0;
      s2 <= '0;
      s3 <= '0;
      s4 <= '0;
      e1_reg <= '0;
      e2_reg <= '0;
      y_reg <= '0;
      y1_reg1 <= '0;
      y1_reg2 <= '0;
      y2_reg <= '0;
      y2_prev1 <= '0;
      y2_prev2 <= '0;
      y3_prev1 <= '0;
      y3_prev2 <= '0;
      y_code <= '0;
      y_bit <= 1'b1;
      v1_state <= '0;
      v2_state <= '0;
    end else if (enable) begin
      s1 <= n1;
      s2 <= n2;
      s3 <= n3;
      s4 <= n4;
      e1_reg <= n1;
      e2_reg <= n2;
      y_reg <= y_next;
      y1_reg1 <= q1_code;
      y1_reg2 <= y1_reg1;
      y2_reg <= q2_code;
      y2_prev1 <= (MB_ALGORITHM == 5) ? y2_reg : q2_code;
      y2_prev2 <= y2_prev1;
      y3_prev1 <= q3_code;
      y3_prev2 <= y3_prev1;
      y_code <= y_next;
      y_bit <= (y_next >= 0);
      v1_state <= y1;
      v2_state <= y2;
    end
  end

endmodule

`default_nettype wire
