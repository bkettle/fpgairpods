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
    
    logic reset; assign reset = btnu;

		///////////////////////////////////////////////////////////////////////////////
		//////
		////// Hardware Interfaces 
		//////
		///////////////////////////////////////////////////////////////////////////////

		////////////////////////////////////
		// Interface with I2S Peripherals
		// (ambient and feedback mics)
		////////////////////////////////////
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

		//////////////////////////////////
		// Interface with Headphone Jack
		// (provides music samples)
		//////////////////////////////////
		logic [15:0] music_unsigned;
		logic music_ready;
		xadc_wiz_0 music_adc ( .dclk_in(clk_100mhz), .daddr_in(8'h13), //read from 0x13 for a
												.vauxn3(vauxn3),.vauxp3(vauxp3),
												.vp_in(1),.vn_in(1),
												.di_in(16'b0),
												.do_out(music_unsigned),
												.drdy_out(music_ready),
												.den_in(1), .dwe_in(0));

		logic signed [15:0] music_sample;
		assign music_sample = music_unsigned - 32767;

		logic [7:0] music_delay_factor; // set by VIO
		logic [7:0] music_scale_factor;
		logic signed [15:0] music_scaled;
		delay_and_scale music_scaler(
			.clk_in(clk_100mhz),
			.reset_in(btnd),
			.ready_in(music_ready),
			.done_out(),
			.delay_in(music_delay_factor), 
			.scale_in(music_scale_factor),
			.signal_in(music_sample),
			.signal_out(music_scaled)
		);

		//////////////////////////////////
		// Output to Speaker
		//////////////////////////////////
		logic signed [15:0] antinoise_out;
		logic signed [15:0] speaker_out;
		logic error_locked; // assigned in error calculator module -- whether coeffs are converged

		logic signed [15:0] switched_music;
		assign switched_music = error_locked ? music_scaled : 0; // only play when converged

		// assign speaker_out to the combination of 
		// antinoise and music
		assign speaker_out = (sw[1] ? antinoise_out : 0) + (sw[2] ? switched_music : 0);

		logic signed [7:0] speaker_out_switched;
		always_comb begin
			 speaker_out_switched = speaker_out[8:1];
		end

		logic pwm_val; //pwm signal (HI/LO)
		pwm pwm (
			.clk_in(clk_100mhz), 
			.rst_in(btnd), 
			.level_in({~speaker_out_switched[7], speaker_out_switched[6:0]}), 
			.pwm_out(pwm_val)
		);
		assign aud_pwm = pwm_val ? 1'bZ : 1'b0;

		assign aud_sd = 1;
		

		/////////////////////////////////
		// Get values from VIO 
		/////////////////////////////////
		
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
			.probe_out6(unlock_high),
			.probe_out7(music_delay_factor),
			.probe_out8(music_scale_factor)
		);

		///////////////////////////////////////////////////////////////////////////////
		//////
		////// Main Active Noise Cancellation Logic
		//////
		///////////////////////////////////////////////////////////////////////////////

		
    
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
		assign led[15] = error_locked;
    error_calculator find_error(.feedback_in(lp_feedback_out),//[25:10]),
                                .error_out(error),
                                .nc_on(sw[0]), // sw[0] will lock coeffs when it's 0
                                .rst_in(btnd),
                                .clk_in(clk_100mhz),
                                .error_ready(lp_ambient_done),
                                .lock_low_in(lock_low),
                                .lock_high_in(lock_high),
                                .unlock_low_in(unlock_low),
                                .unlock_high_in(unlock_high),
                                .error_locked_out(error_locked),
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
		logic signed [15:0] fir_out; 
		logic delay_start;
    fir63 fir_filter(.clk_in(clk_100mhz),
                     .rst_in(btnd),
                     .ready_in(lms_done),
                     .sample(sample),
                     .offset(offset),
                     .weights_in(coeffs),
                     .signal_out(fir_out),
                     .done_out(delay_start));

		// manually apply delay and scale adjustment to output
		logic delay_done;
		delay_and_scale delay_and_scale(
			.clk_in(clk_100mhz),
			.reset_in(btnd),
			.ready_in(delay_start),
			.done_out(delay_done),
			.delay_in(delay_factor), // allow dynamically setting the delay by using switches 9-2
			.scale_in(scale_factor), // set scale using top 5 switches
			.signal_in(fir_out),
			.signal_out(antinoise_out)
		);
    
		///////////////////////////////
		// Monitor Signals for Debug
		///////////////////////////////
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
			.probe8(antinoise_out),
			.probe9(music_sample)
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
