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

	assign aud_sd = 1;
	//assign led = sw; //just to look pretty 

	// for fpgairpods, we replace this with the i2s module
	//xadc_wiz_0 my_adc ( .dclk_in(clk_100mhz), .daddr_in(8'h13), //read from 0x13 for a
	//                    .vauxn3(vauxn3),.vauxp3(vauxp3),
	//                    .vp_in(1),.vn_in(1),
	//                    .di_in(16'b0),
	//                    .do_out(adc_data),.drdy_out(adc_ready),
	//                    .den_in(1), .dwe_in(0));
	//
	

	logic [15:0] test_sample_left;
	logic [15:0] test_sample_right;
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
	
  recorder myrec( 
		.clk_in(clk_100mhz),
		.rst_in(reset),
    .record_in(btnc),
		.ready_in(sample_pulse),
    .filter_in(sw[0]),
		.echo_in(sw[1]),
		.mic_in(test_sample_left[11:4]),
    .data_out(recorder_data), 
		.recording_led_out(led[15]),
		.playback_led_out(led[14]), 
		.mem_full_led_out(led[13]),
		.filtering_led_out(led[12])
	);   
                                                                                            
    volume_control vc (.vol_in(sw[15:13]),
                       .signal_in(recorder_data), .signal_out(vol_out));
    pwm (.clk_in(clk_100mhz), .rst_in(btnd), .level_in({~vol_out[7],vol_out[6:0]}), .pwm_out(pwm_val));
    assign aud_pwm = pwm_val?1'bZ:1'b0; 
    
endmodule





///////////////////////////////////////////////////////////////////////////////
//
// Record/playback
//
///////////////////////////////////////////////////////////////////////////////


module recorder(
  input logic clk_in,              // 100MHz system clock
  input logic rst_in,               // 1 to reset to initial state
  input logic record_in,            // 0 for playback, 1 for record
  input logic ready_in,             // 1 when data is available
  input logic filter_in,            // 1 when using low-pass filter
  input logic echo_in, 				// 1 when echo should be applied
  input logic signed [7:0] mic_in,         // 8-bit PCM data from mic
  output logic signed [7:0] data_out,       // 8-bit PCM data to headphone
  output logic recording_led_out, // 1 when recording, 0 otherwise
  output logic playback_led_out, // 1 when playing back
  output logic mem_full_led_out, // 1 when in MEM_FULL state
  output logic filtering_led_out // 1 when filtering
);

	parameter MEMORY_SIZE = 64000; // the size of the audio memory - for calculating when full

    logic [7:0] tone_750;
    logic [7:0] tone_440;
    //generate a 750 Hz tone
    sine_generator  tone750hz (   .clk_in(clk_in), .rst_in(rst_in), 
                                 .step_in(ready_in), .amp_out(tone_750));
    //generate a 440 Hz tone
    sine_generator  #(.PHASE_INCR(32'd39370534)) tone440hz(.clk_in(clk_in), .rst_in(rst_in), 
                               .step_in(ready_in), .amp_out(tone_440));                          

	
	logic signed [7:0] filter_input; // input for the filter, will be attached to mux
	logic signed [17:0] filter_output; // output, also muxed
	fir31 fir(
	  .clk_in(clk_in),
	  .rst_in(rst_in),
	  .ready_in(ready_in),
	  .x_in(filter_input),
	  .y_out(filter_output)
	);

    logic [7:0] data_to_bram; // data to write to the bram (the current byte)
    logic [7:0] data_from_bram; // data read from the bram (the current byte)
    logic [15:0] bram_addr; // next address to write to / read from in the bram
    logic bram_write; // 1 to write from the bram, 0 to read
    blk_mem_gen_0 audio_bram(.addra(bram_addr), .clka(clk_in), .dina(data_to_bram), .douta(data_from_bram), 
                    .ena(1), .wea(bram_write));                                  

	// let's try agan with a state machine
	logic [1:0] state;
	parameter STATE_STARTUP = 2'b00;
	parameter STATE_RECORDING = 2'b01;
	parameter STATE_REC_MEM_FULL = 2'b10;
	parameter STATE_PLAYBACK = 2'b11;

	assign recording_led_out = state == STATE_RECORDING;
	assign playback_led_out = state == STATE_PLAYBACK;
	assign mem_full_led_out = state == STATE_REC_MEM_FULL;
	assign filtering_led_out = filter_in;

	logic [2:0] eight_period_counter; // used for up and down sampling (when 0) 
	logic [15:0] max_recorded_addr; // the last memory addr written to in prev recording
    logic [15:0] addr; // address of current sample, different from bram_addr to allow
		// looking up other samples while we playback (for echo effect)

	// used to generate the echo
	logic signed [9:0] running_echo_sum; // we'll do fractions of 4 then take the top 8 bits
	// offsets and coeffs for the echo effect - coeffs are max 4
	// we save sample at 6 ksps, so for echo spaced by .5s, interval is 3000
	// samples
	parameter ECHO_OFFSET_1 = 3000;
	parameter ECHO_OFFSET_2 = 6000;
	parameter ECHO_OFFSET_3 = 9000;
	parameter signed ECHO_COEFF_0 = 4; // for the most recent value (offset 0). -> 10 bits
	parameter signed ECHO_COEFF_1 = 3; // value behind most recent value by OFFSET_1
	parameter signed ECHO_COEFF_2 = 2; // behind by OFFSET_2
	parameter signed ECHO_COEFF_3 = 1; // behind by OFFSET_3

	// the input with any processing applied, will be muxed from filter/raw
	logic signed [7:0] processed_input; // used in RECORDING

	// different output options - will be assigned in PLAYBACK
	logic signed [7:0] replicated_out; // upsampled by replicating most recent value
	logic signed [7:0] zero_expanded_out; // upsampled by filling with zeros
	logic signed [7:0] echo_zero_expanded_out; // uses previous terms to create echo

	// main state machine
	// handles writing to and reading from bram
	// this entire thing is so gross but it all has to access the same bram so
	// I feel like I can't really split it up into modules or anything
	// I could probably split it into a few different always_ff things but I
	// don't thik that would clean it up a whole lot
	always_ff @(posedge clk_in) begin
		if (rst_in) begin
			state <= STATE_STARTUP;
		end else begin
			case (state)
				STATE_STARTUP: begin
					// initialize values and wait for record button
					max_recorded_addr <= 0;
					eight_period_counter <= 0;
					replicated_out <= 0; // no output until playback
					zero_expanded_out <= 0;

					// set top bram value top zero for placeholder use
					// we'll mux in a zero down below
					bram_addr <= MEMORY_SIZE - 1;
					bram_write <= 1;
					
					// start recording when button is pushed
					if (record_in) state <= STATE_RECORDING;
				end

				STATE_RECORDING: begin
					if (!record_in) begin
						// button released, exit to playback mode
						state <= STATE_PLAYBACK;
						max_recorded_addr <= addr;
						bram_addr <= 0; // start bram fetching first sample 
						addr <= 0; // playback starts on first sample
						eight_period_counter <= 3'b001; // give time for bram to get first val
						bram_write <= 0; // don't write in playback mode
					end else if (addr >= MEMORY_SIZE - 1) begin
						// memory full (we just wrote 2nd to last addr)
						// last spot in memory is never used, but this way we
						// don't send invalid addresses to the bram
						// there's probably a better way, or maybe it's okay
						// to send invalid addresses to the bram?
						max_recorded_addr <= addr;
						state <= STATE_REC_MEM_FULL;
						bram_write <= 0; // don't write in playback mode
					end else if (ready_in) begin
						// new sample available
						if (eight_period_counter == 0) begin
							// it's time to save a new value
							data_to_bram <= processed_input; // send current mic value to bram
							bram_write <= 1'b1; // tell the bram to save the current byte
							bram_addr <= addr + 1; // start bram writing that address
							addr <= addr + 1; // after writing, move to the next address
						end else bram_write <= 0; // bram_write should be a pulse I think
						
						// increment periodic counter (or loop it around)
						eight_period_counter <= eight_period_counter + 1;
						replicated_out <= 0; // no playback in record mode
						zero_expanded_out <= 0;
					end

				end

				STATE_REC_MEM_FULL: begin
					// just wait for the button to be released
					if (!record_in) begin
						addr <= 0; // prepare to start playback
						bram_addr <= 0; // make bram start fetching first sample
						eight_period_counter <= 3'b001; // give time for bram to get first val
						state <= STATE_PLAYBACK; // start playing back once released
					end
				end

				STATE_PLAYBACK: begin
				if (record_in) begin
						// start recording again
						state <= STATE_RECORDING;
						addr <= 0; // start record on first address
						eight_period_counter <= 0; // save first avail sample
					end else if (addr == max_recorded_addr) begin
						// once we reach the last address recorded
						// recorded, reset the address to 0. this will cause
						// the last address to never be played, but it makes
						// sure we don't pass any addresses outside the range
						// of the bram's range
						//
						// This will cause
						// the DRAM to need to start fetching that address,
						// but this should happen on the clock cycle after the
						// last valid address is written out, so there is
						// still enough time in the 8-cycle window for the
						// DRAM to update by the time we read from it next.
						bram_addr <= 0;
						addr <= 0; // restart our primary address counter
						// keep period counter in sync so that the value we
						// care about will come up when the counter = 2 (the
						// bram has a latency of 2 clock cycles)
						eight_period_counter <= 3'b000; // this will probably
							// not be quite right at the end, but it shouldn't
							// effect it outside of that
					end else if (ready_in) begin
						// pulse of the 44khz sampling rate
						case (eight_period_counter)
							// handle requesting addresses
							// these all have a lot of extra time as I was
							// initially thinking this was counting clock
							// cycles but it's not--however, the value will
							// remain in the bram output until we change the
							// address, so it will still work
							0: begin
								// if we requested an 3rd echo sample
								// previously, it should be back now
								// so output all four addded together
								// we ignore the upper two bits of the running
								// echo sum because they probably won't be
								// used most of the time
								echo_zero_expanded_out <= running_echo_sum[7:0] + data_from_bram;

								// request the primary addr from bram
								bram_addr <= addr; // will take 2 cycles to return
								running_echo_sum <= 0; // we're starting a new sum
							end
							2: begin
								// the sample at addr should be ready
								replicated_out <= data_from_bram;
								zero_expanded_out <= data_from_bram;
								// output the finished sum from the previous
								// address (echo output will be delayed by
								// 1 sample)
								echo_zero_expanded_out <= running_echo_sum[7:0];
								running_echo_sum <= running_echo_sum + data_from_bram;
								// request the first value we need for the echo sum
								if (addr >= ECHO_OFFSET_1)
									// only request it if we're far enough in
									// otherwise we'll just use the main value
									// again
									bram_addr <= addr - ECHO_OFFSET_1;
								else bram_addr <= MEMORY_SIZE - 1; // this holds a zero 
							end
							4: begin
								// offset 1 sample should be ready now
								running_echo_sum <= running_echo_sum + data_from_bram;


								// request the third value we need for the echo sum
								if (addr >= ECHO_OFFSET_2)
									// only request it if we're far enough in
									bram_addr <= addr - ECHO_OFFSET_2;
								else bram_addr <= MEMORY_SIZE - 1;
							end
							6: begin
								// offset 2 sample should be ready now
								running_echo_sum <= running_echo_sum + data_from_bram;


								// request the third value we need for the echo sum
								// it will come back when the counter is
								// 0 again
								if (addr >= ECHO_OFFSET_3)
									// only request it if we're far enough in
									bram_addr <= addr - ECHO_OFFSET_3;
								else bram_addr <= MEMORY_SIZE - 1;

								// we've done all the requesting we need to
								// with this address, so we can finally
								// increment it
								addr <= addr + 1;
							end
							default: begin
								// add infill 0s to zero expanded ones
								// replicated one will stay untouched
								// this will apply immediately after they are
								// set, so we don't need to do this anywhere
								// else (the value of 0 will remain)
								zero_expanded_out <= 0;
								echo_zero_expanded_out <= 0;
							end	
						endcase 

						// increment periodic counter or loop it around to 0
						eight_period_counter <= eight_period_counter + 1;
					end
				end
				default: begin
					state <= STATE_STARTUP;
				end
			endcase
		end
	end

	// mux the inputs/outputs based on state and filter_in 
	// if the state has a glitch, it could propagate to the output here,
		// but because state transitions are only triggered by user input
		// and the output only goes into human ears, it shouldn't matter
	always_comb begin
		case (state) 
			STATE_RECORDING: begin
				filter_input = 
					filter_in ? 
					mic_in : // if filtering, use 8x the filter output to offset gain
					0; // assign to current mic input if we aren't filtering
				processed_input = 
					filter_in ? 
					filter_output[17:10] : // if filtering, use 8x the filter output to offset gain
					mic_in; // assign to current mic input if we aren't filtering
				data_out = processed_input; // when recording, output is same as dram input
			end
			STATE_PLAYBACK: begin
				filter_input = 
					filter_in ? // if filter is on, pass zero-expanded samples for upsampling
					(echo_in ? echo_zero_expanded_out : zero_expanded_out) : 
					0; // no input if not filtering 
				processed_input = 0; // no input to dram in playback
				data_out =  // assign output according to whether or not we're filtering 
					filter_in ? 
					filter_output[14:7] : // if filtering, use 8x the filter output to offset gain
					replicated_out; // if not filtering, upsample by just replicating 
			end
			default: begin
				// otherwise (startup or mem full waiting) just output nothing
				filter_input = 0;
				processed_input = 0;
				data_out = 0;
			end	
		endcase
	end
endmodule                              



///////////////////////////////////////////////////////////////////////////////
//
// 31-tap FIR filter, 8-bit signed data, 10-bit signed coefficients.
// ready is asserted whenever there is a new sample on the X input,
// the Y output should also be sampled at the same time.  Assumes at
// least 32 clocks between ready assertions.  Note that since the
// coefficients have been scaled by 2**10, so has the output (it's
// expanded from 8 bits to 18 bits).  To get an 8-bit result from the
// filter just divide by 2**10, ie, use Y[17:10].
//
///////////////////////////////////////////////////////////////////////////////

module fir31(
  input  clk_in,rst_in,ready_in,
  input signed [7:0] x_in,
  output logic signed [17:0] y_out
);

	logic signed [7:0] sample [31:0];  // 32 element array each 8 bits wide
	logic [4:0] offset; // pointer to the last element inserted in sample 

	logic [4:0] index; // rel. to most recent sample, ie index 1 is prev sample 
	logic signed [9:0] curr_coeff; // will always hold current coeff
	coeffs31 coeffs(.index_in(index), .coeff_out(curr_coeff)); // lookup coeff

	logic signed [17:0] accumulator; // store running sum, size from given y_out size

	logic working; // 1 while the system is doing the sum, 0 while idle 

	always_ff @(posedge clk_in) begin
		if (rst_in) begin
			// reset to known values
			for (integer i=0; i<32; i++) begin
				sample[i] <= 0; // assign all bytes of sample to 0
			end
			offset <= 0; // start at position 0 of sample
			index <= 0; 
			accumulator <= 0;
		end else if (ready_in) begin
			// save the current input in the slot of the oldest sample 
			sample[offset] <= x_in;

			// clear the accumulator and signal to begin adding
			accumulator <= 0;
			working <= 1;
			index <= 0;
		end else if (working) begin
			// currently looping over data, so continue
			// increment by coeff for current rel. index multiplied by 
			// the actual value of that sample.
			// offset stores position of the most recent sample stored
			// and older values are stored in lower positions, so we find the
			// position of the value we care about by subtracting the relative
			// age (index) from the most recent sample's position.
			accumulator <= accumulator + (curr_coeff * sample[offset-index]);

			if (index == 30) begin
				// we are currently processing the last value, so after this
				// the sum will be complete. 
				working <= 0;
				offset <= offset + 1; // increment to point at spot for next sample
			end else index <= index + 1; // prepare to add the next value
		end else begin
			// not working, so the value in accumulator should be the last
			// result
			y_out <= accumulator;
		end
	end

endmodule





///////////////////////////////////////////////////////////////////////////////
//
// Coefficients for a 31-tap low-pass FIR filter with Wn=.125 (eg, 3kHz for a
// 48kHz sample rate).  Since we're doing integer arithmetic, we've scaled
// the coefficients by 2**10
// Matlab command: round(fir1(30,.125)*1024)
//
///////////////////////////////////////////////////////////////////////////////

module coeffs31(
  input  [4:0] index_in,
  output logic signed [9:0] coeff_out
);
  logic signed [9:0] coeff;
  assign coeff_out = coeff;
  // tools will turn this into a 31x10 ROM
  always_comb begin
    case (index_in)
      5'd0:  coeff = -10'sd1;
      5'd1:  coeff = -10'sd1;
      5'd2:  coeff = -10'sd3;
      5'd3:  coeff = -10'sd5;
      5'd4:  coeff = -10'sd6;
      5'd5:  coeff = -10'sd7;
      5'd6:  coeff = -10'sd5;
      5'd7:  coeff = 10'sd0;
      5'd8:  coeff = 10'sd10;
      5'd9:  coeff = 10'sd26;
      5'd10: coeff = 10'sd46;
      5'd11: coeff = 10'sd69;
      5'd12: coeff = 10'sd91;
      5'd13: coeff = 10'sd110;
      5'd14: coeff = 10'sd123;
      5'd15: coeff = 10'sd128;
      5'd16: coeff = 10'sd123;
      5'd17: coeff = 10'sd110;
      5'd18: coeff = 10'sd91;
      5'd19: coeff = 10'sd69;
      5'd20: coeff = 10'sd46;
      5'd21: coeff = 10'sd26;
      5'd22: coeff = 10'sd10;
      5'd23: coeff = 10'sd0;
      5'd24: coeff = -10'sd5;
      5'd25: coeff = -10'sd7;
      5'd26: coeff = -10'sd6;
      5'd27: coeff = -10'sd5;
      5'd28: coeff = -10'sd3;
      5'd29: coeff = -10'sd1;
      5'd30: coeff = -10'sd1;
      default: coeff = 10'hXXX;
    endcase
  end
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




//Sine Wave Generator
module sine_generator ( input clk_in, input rst_in, //clock and reset
                        input step_in, //trigger a phase step (rate at which you run sine generator)
                        output logic [7:0] amp_out); //output phase   
    parameter PHASE_INCR = 32'b1000_0000_0000_0000_0000_0000_0000_0000>>5; //1/64th of 48 khz is 750 Hz
    logic [7:0] divider;
    logic [31:0] phase;
    logic [7:0] amp;
    assign amp_out = {~amp[7],amp[6:0]};
    sine_lut lut_1(.clk_in(clk_in), .phase_in(phase[31:26]), .amp_out(amp));
    
    always_ff @(posedge clk_in)begin
        if (rst_in)begin
            divider <= 8'b0;
            phase <= 32'b0;
        end else if (step_in)begin
            phase <= phase+PHASE_INCR;
        end
    end
endmodule

//6bit sine lookup, 8bit depth
module sine_lut(input[5:0] phase_in, input clk_in, output logic[7:0] amp_out);
  always_ff @(posedge clk_in)begin
    case(phase_in)
      6'd0: amp_out<=8'd128;
      6'd1: amp_out<=8'd140;
      6'd2: amp_out<=8'd152;
      6'd3: amp_out<=8'd165;
      6'd4: amp_out<=8'd176;
      6'd5: amp_out<=8'd188;
      6'd6: amp_out<=8'd198;
      6'd7: amp_out<=8'd208;
      6'd8: amp_out<=8'd218;
      6'd9: amp_out<=8'd226;
      6'd10: amp_out<=8'd234;
      6'd11: amp_out<=8'd240;
      6'd12: amp_out<=8'd245;
      6'd13: amp_out<=8'd250;
      6'd14: amp_out<=8'd253;
      6'd15: amp_out<=8'd254;
      6'd16: amp_out<=8'd255;
      6'd17: amp_out<=8'd254;
      6'd18: amp_out<=8'd253;
      6'd19: amp_out<=8'd250;
      6'd20: amp_out<=8'd245;
      6'd21: amp_out<=8'd240;
      6'd22: amp_out<=8'd234;
      6'd23: amp_out<=8'd226;
      6'd24: amp_out<=8'd218;
      6'd25: amp_out<=8'd208;
      6'd26: amp_out<=8'd198;
      6'd27: amp_out<=8'd188;
      6'd28: amp_out<=8'd176;
      6'd29: amp_out<=8'd165;
      6'd30: amp_out<=8'd152;
      6'd31: amp_out<=8'd140;
      6'd32: amp_out<=8'd128;
      6'd33: amp_out<=8'd115;
      6'd34: amp_out<=8'd103;
      6'd35: amp_out<=8'd90;
      6'd36: amp_out<=8'd79;
      6'd37: amp_out<=8'd67;
      6'd38: amp_out<=8'd57;
      6'd39: amp_out<=8'd47;
      6'd40: amp_out<=8'd37;
      6'd41: amp_out<=8'd29;
      6'd42: amp_out<=8'd21;
      6'd43: amp_out<=8'd15;
      6'd44: amp_out<=8'd10;
      6'd45: amp_out<=8'd5;
      6'd46: amp_out<=8'd2;
      6'd47: amp_out<=8'd1;
      6'd48: amp_out<=8'd0;
      6'd49: amp_out<=8'd1;
      6'd50: amp_out<=8'd2;
      6'd51: amp_out<=8'd5;
      6'd52: amp_out<=8'd10;
      6'd53: amp_out<=8'd15;
      6'd54: amp_out<=8'd21;
      6'd55: amp_out<=8'd29;
      6'd56: amp_out<=8'd37;
      6'd57: amp_out<=8'd47;
      6'd58: amp_out<=8'd57;
      6'd59: amp_out<=8'd67;
      6'd60: amp_out<=8'd79;
      6'd61: amp_out<=8'd90;
      6'd62: amp_out<=8'd103;
      6'd63: amp_out<=8'd115;
    endcase
  end
endmodule

