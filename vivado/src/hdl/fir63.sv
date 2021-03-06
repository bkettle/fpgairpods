`timescale 1ns / 1ps

module fir63(
  input clk_in,rst_in,ready_in,
  input signed [15:0] sample [63:0],
  input [5:0] offset,
  input signed [9:0] weights_in [63:0],
  output logic signed [15:0] signal_out,
  output logic done_out
);

  logic [5:0] index;
  logic signed [25:0] accumulator;

  logic done_triggered; // 1 after done_out is triggered
  
  // parameters used in ff
  parameter MAX_CLOCK_CYCLES = 63;
  
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        // reset indexes, outputs and samples
        index <= 0;
        accumulator <= 0;
        signal_out <= 0;
    end else begin
        if (ready_in) begin
            // ready_in increment offset, set samples
            // reset index and accumulator  
            index <= 0;
            accumulator <= 0;
            done_triggered <= 0;
            done_out <= 0;
        end else begin
            if (index < MAX_CLOCK_CYCLES) begin
                // running sum of coeff * samples[offset-index]
                accumulator <= accumulator + weights_in[index]*sample[offset-index];
                index <= index + 1;
                done_out <= 0;
            end else begin 
                signal_out <= accumulator[25:10];
                // make done_out a pulse
                done_out <= ~done_triggered;
                done_triggered <= 1;
            end
       end
    end
  end
endmodule
