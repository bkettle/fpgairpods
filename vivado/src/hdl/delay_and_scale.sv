`timescale 1ns / 1ps

module delay_and_scale(
		input clk_in,
		input reset_in,
		input ready_in,
		output logic done_out,
		input [7:0] delay_in,
		input [4:0] scale_in, // numerator of a fraction over 2^6
		input [15:0] signal_in,
		output logic [15:0] signal_out
  );

	logic signed [15:0] history [255:0];
	logic [7:0] hist_offset;

	logic signed [20:0] unscaled_next_output; // 5 fractional bits
	logic signed [20:0] scaled_next_output; // 5 fractional bits
	always_comb begin
		unscaled_next_output = history[hist_offset - delay_in]; 
		scaled_next_output = unscaled_next_output * scale_in;
	end

	always_ff @(posedge clk_in) begin
		if (reset_in) begin
			hist_offset <= 0;
			signal_out <= 1;
			for (int i=0; i<64; i++)
				history[i] <= 0; // clear all values
		end else if (ready_in) begin
			history[hist_offset] <= signal_in;
			hist_offset <= hist_offset + 1;
			// should multiply ambient sample by some fraction to simulate passive
			// cancellation in the future
			signal_out <= scaled_next_output[20:5];
			done_out <= 1;
		end else done_out <= 0;
	end
endmodule
