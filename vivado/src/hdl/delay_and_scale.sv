`timescale 1ns / 1ps

module delay_and_scale(
		input clk_in,
		input reset_in,
		input ready_in,
		output logic done_out,
		input [7:0] delay_in,
		input [7:0] scale_in, // numerator of a fraction over 2^6
		input signed [15:0] signal_in,
		output logic signed [15:0] signal_out
  );

	logic signed [15:0] history [255:0];
	logic [7:0] hist_offset;
	logic [7:0] curr_index;

	logic signed [8:0] scale_factor;
	assign scale_factor = {1'b0, scale_in}; // make into a signed number
	logic signed [23:0] unscaled_next_output; // 8 fractional bits
	logic signed [23:0] scaled_next_output; // 8 fractional bits
	
	// calculate the next output
	always_comb begin
		curr_index = hist_offset - delay_in - 1;
		unscaled_next_output = history[curr_index];
		scaled_next_output = unscaled_next_output * scale_factor;
	end

	always_ff @(posedge clk_in) begin
		if (reset_in) begin
		    // reset variables
			hist_offset <= 0;
			signal_out <= 1;
			for (int i=0; i<256; i++)
				history[i] <= 0; // clear all values
		end else if (ready_in) begin
			history[hist_offset] <= signal_in;
			hist_offset <= hist_offset + 1;
			// take integer portion for the output
			signal_out <= scaled_next_output[23:8];
			done_out <= 1;
		end else done_out <= 0;
	end
endmodule
