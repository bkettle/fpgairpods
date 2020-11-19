`timescale 1ns / 1ps

module top_level( input clk_100mhz,
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
//    input logic clk_in,
//    input logic rst_in,
//    input logic ready_in,
//    input logic signed [15:0] x_in,
//    output logic signed [15:0] y_out
    );
    
    logic signed [15:0] sample [63:0]; //buffer to hold samples
    logic [5:0] offset; //stores offset for reading from sample buffer
    logic signed [15:0] error; //stores most recent error calculated
    logic signed [9:0] coeffs [63:0]; //holds filter coefficients
    logic lms_done; //signals whether LMS is done updating weights
    
    //I2S INSTANTIATION (SETUP MICS AND SPEAKER)
    logic reset; assign reset = btnu;
	assign ja0 = 1'b0; // test mic should be on the right 
	logic i2s_lrclk_out; assign ja1 = i2s_lrclk_out;
	logic i2s_data_in; assign i2s_data_in = ja2;
	logic i2s_bclk_out; assign ja3 = i2s_bclk_out;

	logic signed [15:0] test_sample_left;
	logic signed [15:0] test_sample_right;
	assign led[0] = i2s_data_in;
	assign led[1] = i2s_bclk_out;
	assign led[2] = i2s_lrclk_out;
	logic sample_pulse;
	i2s_receiver i2s_receiver(
		.clock_in(clk_100mhz),// 100mhz clock in
		.reset_in(btnd), // reset signal -- active high

		// i2s data
		.i2s_bclk_out(i2s_bclk_out), // data clock, should be 4.096 MHz 
		.i2s_data_in(i2s_data_in), // data from the i2s bus
		.i2s_lrclk_out(i2s_lrclk_out), // select the left or right channel
		// datasheet tells us the above must be BCLK/64

		.left_sample_out(test_sample_left), // the left channel's sample
		.right_sample_out(test_sample_right), // the right channel's sample
		.new_sample_out(sample_pulse) // a pulse 1 cycle long when new samples are out
	);
	
	logic signed [15:0] speaker_out;
	logic signed [15:0] speaker_mid;
	logic signed [7:0] speaker_out_switched;
	logic [7:0] vol_out;
	assign aud_sd = 1;
	logic pwm_val; //pwm signal (HI/LO)
	
	always_comb begin
	   speaker_mid = sw[0]?(speaker_out <<< 6): 0;
	   speaker_out_switched = speaker_mid[15:8];
	end
	
	volume_control vc (.vol_in(sw[15:13]),
                       .signal_in(speaker_out_switched), .signal_out(vol_out));
    pwm (.clk_in(clk_100mhz), .rst_in(btnd), .level_in({~vol_out[7],vol_out[6:0]}), .pwm_out(pwm_val));
    assign aud_pwm = pwm_val?1'bZ:1'b0;
    
    //initialize sample buffer instance
    sampler sampler_buffer(.clk_in(clk_100mhz),
                           .rst_in(btnd),
                           .ready_in(sample_pulse),
                           .signal_in(test_sample_right),
                           .sample_out(sample),
                           .offset(offset));
    
    //initialize error calculator instance
		logic [15:0] test_error; assign test_error = speaker_out + test_sample_right;
    error_calculator find_error(.feedback_in(test_error),//[25:10]),
                                .error_out(error),
                                .nc_on(sw[0]),
                                .clk_in(clk_100mhz));
    
    //initialize LMS instance
    LMS lms1(.clk_in(clk_100mhz), 
             .rst_in(btnd),
             .ready_in(sample_pulse),
             .error_in(error),
             .sample_in(sample),
             .offset_in(offset),
             .coeffs_out(coeffs),
             .done(lms_done));
    
    //initialize FIR Filter instance
    fir63 fir_filter(.clk_in(clk_100mhz),
                     .rst_in(btnd),
                     .ready_in(lms_done),
                     .sample(sample),
                     .offset(offset),
                     .weights_in(coeffs),
                     .signal_out(speaker_out));
    
    // ILA TO CHECK I2S
	ila_0 i2s_ila (
		.clk(clk_100mhz),
		.probe0(test_sample_left),
		.probe1(test_sample_right),
		.probe2(speaker_out),
		.probe3(sample_pulse),
		.probe4(speaker_out_switched)
	);
    
endmodule

//Volume Control
module volume_control (input [2:0] vol_in, input signed [7:0] signal_in, output logic signed[7:0] signal_out);
    logic [2:0] shift;
    assign shift = 3'd7 - vol_in;
    assign signal_out = signal_in>>>shift;
endmodule

//PWM generator for audio generation!
module pwm (input clk_in, input rst_in, input [7:0] level_in, output logic pwm_out);
    logic [7:0] count;
    assign pwm_out = count<level_in;
    always_ff @(posedge clk_in)begin
        if (rst_in)begin
            count <= 8'b0;
        end else begin
            count <= count+8'b1;
        end
    end
endmodule
