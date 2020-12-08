`timescale 1ns / 1ps

module sampler(
  input  clk_in,rst_in, ready_in,
  input signed [15:0] signal_in,
  output logic signed [15:0] sample_out [63:0],
  output logic [5:0] offset,
  output logic signed [31:0] norm_out
);
  
  // parameters used in ff
  parameter SAMPLES_SIZE= 64;
  
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        // reset indexes, outputs and samples
        offset <= 0;
        // set all samples in 2d array to 0
        norm_out <= 0;
        for (int i = 0; i < SAMPLES_SIZE; i = i + 1) sample_out[i] <= 0;
    end else begin
        if (ready_in) begin
            // ready_in increment offset, set samples, and calculate the running_sum of norm 
            offset <= offset + 1;
            norm_out <= norm_out - sample_out[offset]*sample_out[offset] + signal_in*signal_in; 
            sample_out[offset] <= signal_in; 
        end
    end
  end
endmodule