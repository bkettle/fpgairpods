`timescale 1ns / 1ps

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
    
    logic signed [15:0] sample [63:0]; //buffer to hold samples
    logic [5:0] offset; //stores offset for reading from sample buffer
    logic signed [15:0] error; //stores most recent error calculated
    logic signed [9:0] coeffs [63:0]; //holds filter coefficients
    logic lms_done; //signals whether LMS is done updating weights
    logic signed [31:0] norm;
    
    //I2S INSTANTIATION (SETUP MICS AND SPEAKER)
    logic reset; assign reset = btnu;

		logic i2s_lrclk_out; assign ja1 = i2s_lrclk_out;
		logic i2s_data_in; assign i2s_data_in = ja2;
		logic i2s_bclk_out; assign ja3 = i2s_bclk_out;

		logic signed [15:0] feedback_sample;
		logic signed [15:0] ambient_sample;
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

			.left_sample_out(feedback_sample), // the left channel's sample
			.right_sample_out(ambient_sample), // the right channel's sample
			.new_sample_out(sample_pulse) // a pulse 1 cycle long when new samples are out
		);
	
		logic signed [15:0] speaker_out;
		logic signed [15:0] speaker_delayed;
		logic signed [7:0] speaker_out_switched;
		logic [7:0] vol_out;
		assign aud_sd = 1;
		logic pwm_val; //pwm signal (HI/LO)
		
		always_comb begin
			 speaker_out_switched = sw[1] ? speaker_delayed[8:1]: sw[2] ? speaker_delayed[7:0]: 0;
		end

		logic [7:0] delay_factor;
		logic [7:0] scale_factor;
		logic signed [7:0] lock_low;
		logic signed [7:0] lock_high;
		logic signed [7:0] unlock_low;
		logic signed [7:0] unlock_high;
		logic [10:0] manual_offset;
		vio_0 vio(
			.clk(clk_100mhz),
			.probe_out0(delay_factor),
			.probe_out1(scale_factor),
			.probe_out2(lock_low),
			.probe_out3(lock_high),
			.probe_out4(manual_offset),
			.probe_out5(unlock_low),
			.probe_out6(unlock_high)
		);

		logic delay_done;
		logic delay_start;
		delay_and_scale delay_and_scale(
			.clk_in(clk_100mhz),
			.reset_in(btnd),
			.ready_in(delay_start),
			.done_out(delay_done),
			.delay_in(delay_factor), // allow dynamically setting the delay by using switches 9-2
			.scale_in(scale_factor), // set scale using top 5 switches
			.signal_in(speaker_out),
			.signal_out(speaker_delayed)
		);
		
		pwm pwm (
			.clk_in(clk_100mhz), 
			.rst_in(btnd), 
			.level_in({~speaker_out_switched[7], speaker_out_switched[6:0]}), 
			.pwm_out(pwm_val)
		);
		assign aud_pwm = pwm_val ? 1'bZ : 1'b0;
    
    //initialize dc_remover instance
    logic signed [15:0] dc_ambient_out;
    logic dc_ambient_done;
    dc_remover remove_dc_ambient(.clk_in(clk_100mhz),
                                 .rst_in(btnd),
                                 .ready_in(sample_pulse),
                                 .signal_in(ambient_sample),
                                 .signal_out(dc_ambient_out),
                                 .done_out(dc_ambient_done));
    
    //initialize dc_remover instance
    logic signed [15:0] dc_feedback_out;
    logic dc_feedback_done;
    dc_remover remove_dc_feedback(.clk_in(clk_100mhz),
                                  .rst_in(btnd),
                                  .ready_in(sample_pulse),
                                  .signal_in(feedback_sample),
                                  .signal_out(dc_feedback_out),
                                  .done_out(dc_feedback_done));
    
    logic lp_ambient_done; //pulse when lowpass is done computing (ambient)
    logic signed [15:0] lp_ambient_out; //output of lowpass filter (ambient)
    logic lp_ambient_start;
    logic signed [15:0] lp_ambient_in;
    assign lp_ambient_start = sw[4]?dc_ambient_done: sample_pulse;
    assign lp_ambient_in = sw[4]?dc_ambient_out: manual_offset+ambient_sample;
    //initialize lowpass instance for ambient noise
    lowpass lp_ambient(
			.clk_in(clk_100mhz),
			.rst_in(btnd),
			.ready_in(lp_ambient_start),
			.done_out(lp_ambient_done),
			.signal_in(lp_ambient_in),
			.signal_out(lp_ambient_out)
		);
    
    logic lp_feedback_done; //pulse when lowpass is done computing (feedback)
    logic signed [15:0] lp_feedback_out; //output of lowpass filter (feedback)
    logic lp_feedback_start;
    logic signed [15:0] lp_feedback_in;
    assign lp_feedback_start = sw[4]?dc_feedback_done: sample_pulse;
    assign lp_feedback_in = sw[4]?dc_feedback_out: manual_offset+feedback_sample;            
     //initialize lowpass instance for feedback
    lowpass lp_feedback(.clk_in(clk_100mhz),
                      .rst_in(btnd),
                      .ready_in(lp_feedback_start),
                      .done_out(lp_feedback_done),
                      .signal_in(lp_feedback_in),
                      .signal_out(lp_feedback_out));
    
    //initialize sample buffer instance
    sampler sampler_buffer(.clk_in(clk_100mhz),
                           .rst_in(btnd),
                           .ready_in(lp_ambient_done),
                           .signal_in(lp_ambient_out),
                           .sample_out(sample),
                           .norm_out(norm),
                           .offset(offset)
												);
    
    //initialize error calculator instance
    logic error_done;
    error_calculator find_error(.feedback_in(lp_feedback_out),//[25:10]),
                                .error_out(error),
                                .nc_on(sw[0]),
                                .rst_in(btnd),
                                .clk_in(clk_100mhz),
                                .error_ready(lp_ambient_done),
                                .lock_low_in(lock_low),
                                .lock_high_in(lock_high),
                                .unlock_low_in(unlock_low),
                                .unlock_high_in(unlock_high),
                                .error_locked_out(led[15]),
                                .done_out(error_done)
															);
    
    //initialize LMS instance
    NLMS nlms1(.clk_in(clk_100mhz), 
             .rst_in(btnd),
             .ready_in(error_done),
             .error_in(error),
             .sample_in(sample),
             .norm_in(norm),
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
                     .signal_out(speaker_out),
                     .done_out(delay_start));
    
    // ILA TO CHECK I2S
		ila_0 i2s_ila (
			.clk(clk_100mhz),
			.probe0(error),
			.probe1(ambient_sample),
			.probe2(speaker_out_switched),
			.probe3(sample_pulse),
			.probe4(speaker_out),
			.probe5(lp_feedback_out),
			.probe6(lp_ambient_out),
			.probe7(feedback_sample),
			.probe8(speaker_delayed)
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
