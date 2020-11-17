`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/14/2020 06:11:22 PM
// Design Name: 
// Module Name: i2s_receiver_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module i2s_receiver_tb();

	logic clock;
	logic reset;

	logic i2s_bclk;
	logic i2s_data;
	logic i2s_lrclk;

	logic [15:0] left_sample;
	logic [15:0] right_sample;
	logic sample_ready;

	always #5 clock = !clock;

	initial begin
		clock = 0;
		i2s_data = 1;
		#10;
		reset = 1;
		#20;
		reset = 0;
		#1000;
	end

	i2s_receiver #(.CLOCK_DIVIDER(2)) i2s_receiver(
			.clock_in(clock), // 100mhz clock in
			.reset_in(reset), // reset signal -- active high

			.i2s_bclk_out(i2s_bclk), // data clock, should be 4.096 MHz 
			.i2s_data_in(i2s_data), // data from the i2s bus
			.i2s_lrclk_out(i2s_lrclk), // select the left or right channel

			.left_sample_out(left_sample), // the left channel's sample
			.right_sample_out(right_sample), // the right channel's sample
			.new_sample_out(sample_ready) // a pulse 1 cycle long when new samples are out
		);
endmodule
