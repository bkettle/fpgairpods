`timescale 1ns / 1ps

module dc_remover(
  input  clk_in,rst_in, ready_in,
  input signed [15:0] signal_in,
  output logic signed [15:0] signal_out,
  output logic done_out
);
  
  // parameters used in ff
  parameter SAMPLES_SIZE= 64;
  
  logic [5:0] offset;
  logic signed [15:0] samples [63:0];
  logic signed [21:0] sample_sum;
  
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        // reset indexes, outputs and samples
        offset <= 0;
        sample_sum <= 0;
        // set all samples in 2d array to 0
        for (int i = 0; i < SAMPLES_SIZE; i = i + 1) samples[i] <= 0;
    end else begin
        if (ready_in) begin
            // ready_in increment offset, set samples
            // reset index and accumulator 
            offset <= offset + 1;
            samples[offset] <= signal_in; 
            sample_sum <= sample_sum - samples[offset] + signal_in;
            signal_out <= signal_in - sample_sum[21:6];
            done_out <= 1;
        end else done_out <= 0;
    end
  end
endmodule