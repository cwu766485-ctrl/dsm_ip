// Common lightweight self-checks for P0 regression testbenches.
// These are intentionally simulator-portable immediate checks rather than a
// full UVM/SVA environment; the MATLAB stage owns metric-level scoreboarding.

int unsigned tb_error_count;

task automatic tb_record_error(input string msg);
  begin
    tb_error_count++;
    $display("ERROR[%0t] %s", $time, msg);
  end
endtask

`define P0_CHECK_KNOWN_1(sig, name) \
  if (^sig === 1'bx) tb_record_error({name, " contains X/Z"})

`define P0_CHECK_KNOWN_VEC(sig, name) \
  if (^sig === 1'bx) tb_record_error({name, " contains X/Z"})

`define P0_SIGNDOMAIN_CHECKS \
  always_ff @(posedge clk) begin \
    if (rst_n) begin \
      if (sample_valid) begin \
        `P0_CHECK_KNOWN_VEC(rom_addr, "rom_addr"); \
        `P0_CHECK_KNOWN_1(i_bit, "i_bit"); \
        `P0_CHECK_KNOWN_1(q_bit, "q_bit"); \
      end \
      if (rf_valid) begin \
        `P0_CHECK_KNOWN_1(rf_bit, "rf_bit"); \
      end \
      if (rom_addr >= DEPTH) begin \
        tb_record_error("rom_addr out of configured range"); \
      end \
    end \
  end

`define P0_MASH_CHECKS(ymin, ymax) \
  always_ff @(posedge clk) begin \
    if (rst_n) begin \
      if (sample_valid) begin \
        `P0_CHECK_KNOWN_VEC(rom_addr, "rom_addr"); \
      end \
      if (dsm_valid) begin \
        `P0_CHECK_KNOWN_VEC(i_yout, "i_yout"); \
        `P0_CHECK_KNOWN_VEC(q_yout, "q_yout"); \
        if ((i_yout < ymin) || (i_yout > ymax)) tb_record_error("i_yout out of MASH bounds"); \
        if ((q_yout < ymin) || (q_yout > ymax)) tb_record_error("q_yout out of MASH bounds"); \
      end \
      if (rf_valid) begin \
        `P0_CHECK_KNOWN_VEC(rf_signed, "rf_signed"); \
      end \
      if (rom_addr >= DEPTH) begin \
        tb_record_error("rom_addr out of configured range"); \
      end \
    end \
  end

task automatic tb_write_summary(
  input string summary_file,
  input string test_name,
  input int unsigned sample_count
);
  integer f_sum;
  begin
    f_sum = $fopen(summary_file, "w");
    if (f_sum == 0) begin
      $display("ERROR: cannot open summary file %s", summary_file);
      tb_error_count++;
    end else begin
      $fwrite(f_sum, "Test,Pass,Samples,Errors\n");
      $fwrite(f_sum, "%s,%0d,%0d,%0d\n", test_name, (tb_error_count == 0), sample_count, tb_error_count);
      $fclose(f_sum);
    end
  end
endtask
