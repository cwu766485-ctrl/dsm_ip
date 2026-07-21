`timescale 1ns/1ps
`default_nettype none

module tb_dpd_tinyml_tree;

  reg feature_valid;
  reg signed [31:0] feature [0:12];
  wire signed [(13*32)-1:0] features_q20;
  wire [2:0] seed_package;
  wire direct;
  wire fallback_required;
  wire local_search_required;
  wire [3:0] decision_path;
  wire [2:0] decision_path_length;
  wire out_of_distribution;

  integer vector_file;
  integer scan_count;
  integer vector_count;
  integer expected_package;
  integer expected_direct;
  integer expected_path;
  integer expected_path_length;
  integer expected_ood;
  reg [8*128-1:0] vector_name;
  reg [8*2048-1:0] header;

  genvar feature_index;
  generate
    for (feature_index = 0; feature_index < 13; feature_index = feature_index + 1) begin : g_pack
      assign features_q20[(feature_index*32) +: 32] = feature[feature_index];
    end
  endgenerate

  dpd_tinyml_tree dut (
    .feature_valid(feature_valid),
    .features_q20(features_q20),
    .seed_package(seed_package),
    .direct(direct),
    .fallback_required(fallback_required),
    .local_search_required(local_search_required),
    .decision_path(decision_path),
    .decision_path_length(decision_path_length),
    .out_of_distribution(out_of_distribution)
  );

  initial begin
    vector_count = 0;
    vector_file = $fopen("memory_tinyml_tree_q20.txt", "r");
    if (vector_file == 0) begin
      $fatal(1, "cannot open memory_tinyml_tree_q20.txt");
    end
    scan_count = $fgets(header, vector_file);
    while (!$feof(vector_file)) begin
      scan_count = $fscanf(vector_file,
          "%s %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
          vector_name, feature_valid,
          feature[0], feature[1], feature[2], feature[3], feature[4],
          feature[5], feature[6], feature[7], feature[8], feature[9],
          feature[10], feature[11], feature[12], expected_package,
          expected_direct, expected_path, expected_path_length, expected_ood);
      if (scan_count == 20) begin
        #1;
        if ((seed_package !== expected_package[2:0]) ||
            (direct !== expected_direct[0]) ||
            (fallback_required !== !expected_direct[0]) ||
            (local_search_required !== !expected_direct[0]) ||
            (decision_path !== expected_path[3:0]) ||
            (decision_path_length !== expected_path_length[2:0]) ||
            (out_of_distribution !== expected_ood[0])) begin
          $display("FAIL %s expected %0d/%0d/%0d/%0d/%0d got %0d/%0d/%0d/%0d/%0d",
              vector_name, expected_package, expected_direct, expected_path,
              expected_path_length, expected_ood, seed_package, direct,
              decision_path, decision_path_length, out_of_distribution);
          $fatal(1, "TinyML tree decision mismatch");
        end
        vector_count = vector_count + 1;
      end else if (!$feof(vector_file)) begin
        $fatal(1, "malformed vector after %0d records (fields=%0d)",
               vector_count, scan_count);
      end
    end
    $fclose(vector_file);
    if (vector_count == 0) begin
      $fatal(1, "no TinyML vectors were read");
    end
    $display("RTL TinyML tree PASS: %0d decisions", vector_count);
    $finish;
  end

endmodule

`default_nettype wire
