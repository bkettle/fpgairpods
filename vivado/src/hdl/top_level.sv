`timescale 1ns / 1ps

//Top level module (should not need to change except to uncomment ADC module)

module top_level(   
		input clk_100mhz,
		input [15:0] sw,
		input btnc, btnu, btnd, btnr, btnl,
		input vauxp3,
		input vauxn3,
		input vn_in,
		input vp_in,
		output logic ja0, // for i2s mic interface testing
		output logic ja1, // for i2s mic interface testing
		input ja2, // for i2s mic interface testing
		output logic ja3, // for i2s mic interface testing
		output logic [15:0] led,
		output logic aud_pwm,
		output logic aud_sd
  );  
	parameter SAMPLE_COUNT = 2082;//gets approximately (will generate audio at approx 48 kHz sample rate.
	
	logic [15:0] sample_counter;
	logic [11:0] adc_data;
	logic [11:0] sampled_adc_data;
	logic sample_trigger;
	logic adc_ready;
	logic enable;
	logic [7:0] recorder_data;             
	logic [7:0] vol_out;
	logic pwm_val; //pwm signal (HI/LO)
	
	// rename input variables
	logic reset; assign reset = btnu;
	assign ja0 = 1'b0; // test mic should be on the right 
	logic i2s_lrclk_out; assign ja1 = i2s_lrclk_out;
	logic i2s_data_in; assign i2s_data_in = ja2;
	logic i2s_bclk_out; assign ja3 = i2s_bclk_out;

	logic [15:0] test_sample_left;
	logic [15:0] test_sample_right;
	assign led[0] = i2s_data_in;
	assign led[1] = i2s_bclk_out;
	assign led[2] = i2s_lrclk_out;
	logic sample_pulse;

	i2s_receiver i2s_receiver(
		.clock_in(clk_100mhz),// 100mhz clock in
		.reset_in(reset), // reset signal -- active high

		// i2s data
		.i2s_bclk_out(i2s_bclk_out), // data clock, should be 4.096 MHz 
		.i2s_data_in(i2s_data_in), // data from the i2s bus
		.i2s_lrclk_out(i2s_lrclk_out), // select the left or right channel
		// datasheet tells us the above must be BCLK/64

		.left_sample_out(test_sample_left), // the left channel's sample
		.right_sample_out(test_sample_right), // the right channel's sample
		.new_sample_out(sample_pulse) // a pulse 1 cycle long when new samples are out
	);
endmodule
