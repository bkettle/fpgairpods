`timescale 1ns / 1ps

module dc_remover(
  input  clk_in,rst_in, ready_in,
  input signed [15:0] signal_in,
  output logic signed [15:0] signal_out,
  output logic done_out
);
  
  parameter SAMPLES_SIZE= 64; // number of raw samples stored
  
  logic [5:0] offset; // offset for accessing circular buffer
  logic signed [15:0] samples [63:0]; // stores raw samples
  logic signed [21:0] sample_sum; // sum of last 64 raw samples (average is considered dc_offset)
  
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        // reset offset and sample_sum
        offset <= 0;
        sample_sum <= 0;
        // set all raw samples in 2d array to 0
        for (int i = 0; i < SAMPLES_SIZE; i = i + 1) samples[i] <= 0;
    end else begin
        if (ready_in) begin
            // on ready_in increment offset, set raw samples, update sample_sum
            offset <= offset + 1;
            samples[offset] <= signal_in; 
            sample_sum <= sample_sum - samples[offset] + signal_in;
            // output signal_in minus the average of the last 64 raw samples (remove dc offset)
            signal_out <= signal_in - sample_sum[21:6];
            done_out <= 1; // trigger done pulse
        end else done_out <= 0;
    end
  end
endmodule