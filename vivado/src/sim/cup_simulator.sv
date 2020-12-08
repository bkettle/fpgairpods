`timescale 1ns / 1ps

//This module simulates the delay and scaling in our physical system
//caused by the distance between the ambient mic and the speaker (delay)
//and the passive filtering of the cup itself (scale)
module cup_simulator(
		input clk_in,
		input reset_in,
		input ready_in,
		output logic done_out,
		input signed [15:0] ambient_sample_in,
		input signed [15:0] speaker_output_in,
		output logic signed [15:0] feedback_sample_out
  );

	parameter SAMPLE_DELAY = 8'd64; //how much to delay
	parameter SAMPLE_SCALE_FACTOR = 8'd128; //how much to scale

	logic signed [15:0] filtered_ambient; 
    
    //use delay and scale module to simulate cup system
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
    
    //output the sum of the speaker output and the cup-filtered ambient input
	assign feedback_sample_out = filtered_ambient + speaker_output_in;
endmodule
