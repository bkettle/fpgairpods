`timescale 1ns / 1ps

module cup_simulator(
		input clk_in,
		input reset_in,
		input ready_in,
		output logic done_out,
		input signed [15:0] ambient_sample_in,
		input signed [15:0] speaker_output_in,
		output logic signed [15:0] feedback_sample_out
  );

	parameter SAMPLE_DELAY = 8'd64;
	parameter SAMPLE_SCALE_FACTOR = 8'd128; // out of 256 

	logic signed [15:0] filtered_ambient; 

	delay_and_scale delay_scale(
		.clk_in(clk_in),
		.reset_in(reset_in),
		.ready_in(ready_in),
		.done_out(done_out),
		.delay_in(SAMPLE_DELAY),
		.scale_in(SAMPLE_SCALE_FACTOR),
		.signal_in(ambient_sample_in),
		.signal_out(filtered_ambient)
	);

	assign feedback_sample_out = filtered_ambient + speaker_output_in;
endmodule
