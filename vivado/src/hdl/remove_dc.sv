`timescale 1ns / 1ps

module remove_dc(
	input clk_in,
	input reset_in,
	input ready_in,
	output logic done_out,
	input signed [15:0] signal_in,
	output logic signed [15:0] signal_out
	);

	parameter ALPHA_MULTIPLIER = 10'sd511;
	// I think because the above is signed, we shift by 1 less?
	// as the max possible multiply value is 2^9 - 1
	parameter ALPHA_SHIFT_SIZE = 9;


	// assign curr_average combinationally
	// based on the last output and current&prev inputs
	// all these variables are fixed point representation
	// with 8 fractional bits
	logic signed [25:0] shifted_prev_signal_in;
	logic signed [25:0] shifted_signal_in;
	logic signed [25:0] shifted_y_prev; 
	logic signed [25:0] shifted_output;

	always_comb begin
		shifted_signal_in = signal_in << ALPHA_SHIFT_SIZE;
		// signal out is the previous signal out
		shifted_output = shifted_signal_in - shifted_prev_signal_in + ALPHA_MULTIPLIER*signal_out;
	end

	always_ff @(posedge clk_in) begin
		if (reset_in) begin 
			signal_out <= 0;
			shifted_prev_signal_in <= 0;
			shifted_y_prev <= 0;
			done_out <= 0;
		end else if (ready_in) begin
			signal_out <= shifted_output[25:10]; // assign top 16 out
			shifted_y_prev <= shifted_output;
			shifted_prev_signal_in <= shifted_signal_in;
			done_out <= 1; // valid value will be outputted
		end else
			done_out <= 0;
	end
endmodule

module remove_dc_two(
	input clk_in,
	input reset_in,
	input ready_in,
	output logic done_out,
	input signed [15:0] signal_in,
	output logic signed [15:0] signal_out
	);

	parameter ALPHA_MULTIPLIER = 9'sd255;
	parameter ALPHA_SHIFT_SIZE = 8;

	logic signed [15:0] w_prev;
	logic signed [15:0] w_new;

	// assign curr_average combinationally
	// based on the last average and current input
	// all these variables are fixed point representation
	// with 8 fractional bits
	logic signed [23:0] shifted_signal_in;
	logic signed [23:0] shifted_w_prev; 
	logic signed [23:0] shifted_w_new;

	always_comb begin
		shifted_signal_in = signal_in << 8;
		shifted_w_prev = w_prev << 8; // move over to integer portion
		shifted_w_new = shifted_signal_in + shifted_w_prev*ALPHA_MULTIPLIER;
	end

	always_ff @(posedge clk_in) begin
		if (reset_in) begin 
			signal_out <= 0;
			w_prev <= 0;
			w_new <= 0;
			done_out <= 0;
		end else if (ready_in) begin
			w_prev <= w_new; // move current value into old
			w_new <= shifted_w_new[23:8]; // take integer part of new value
			signal_out <= shifted_w_new[23:8] - w_new; // assign signal out to the change
			done_out <= 1; // valid value will be outputted
		end else
			done_out <= 0;
	end
endmodule
