`timescale 1ns / 1ps

// this i2s receiver will receive data from 2 microphones
module i2s_receiver(
		input clock_in, // 100mhz clock in
		input reset_in, // reset signal -- active high
		
		// i2s data
		output logic i2s_bclk_out, // data clock, should be 4.096 MHz 
		input i2s_data_in, // data from the i2s bus
		output logic i2s_lrclk_out, // select the left or right channel
		// datasheet tells us the above must be BCLK/64

		output logic [15:0] left_sample_out, // the left channel's sample
		output logic [15:0] right_sample_out, // the right channel's sample
		output logic new_sample_out // a pulse 1 cycle long when new samples are out
	);

	// these are for working versions of the samples
	logic [15:0] curr_left_sample;
	logic [15:0] curr_right_sample;

	// do I need to use a clock wizard or something instead? maybe doesn't
	// matter bc this clock is only being used externally
	parameter CLOCK_DIVISOR = 12; // use this to generate the bclk, change value every 12

	logic [5:0] clk_counter; // counts up to CLOCK_DIVISOR
	logic [4:0] bit_counter; // counts the BCLK cycles since LRCLK switched
	// assign i2s_lrclk_out = bit_counter[5];

	// ILA TO CHECK I2S
	ila_0 i2s_ila (
		.clk(clock_in),
		.probe0(i2s_data_in),
		.probe1(left_sample_out),
		.probe2(right_sample_out),
		.probe3(clk_counter),
		.probe4(bit_counter),
		.probe5(new_sample_out),
		.probe6(i2s_lrclk_out),
		.probe7(i2s_bclk_out)
	);

	always_ff @(posedge clock_in) begin
		if (reset_in) begin
			clk_counter = 0;
			bit_counter = 0;
			i2s_lrclk_out = 0;
			i2s_bclk_out = 0;
			curr_left_sample = 0;
			curr_right_sample = 0;
			left_sample_out = 0;
			right_sample_out = 0;
			new_sample_out = 0;
		end

		if (clk_counter == CLOCK_DIVISOR - 1) begin
			// we do pretty much everything here, this is our 4MHz signal
			i2s_bclk_out <= ~i2s_bclk_out; // invert every clock divisor
			clk_counter <= 0;
			if (!i2s_bclk_out) begin
				// increment bit counter once per clock cycle
				bit_counter <= bit_counter + 1;
			end

			if (bit_counter == 31 && i2s_bclk_out) begin
				// bit_counter will be zero every 2^6 = 32 cycles, so switch
				// bit counter should loop around to zero at the same time this is set
				i2s_lrclk_out <= ~i2s_lrclk_out;
			end

			if (bit_counter == 0 && i2s_lrclk_out == 0 && i2s_bclk_out) begin
				// if we reached the last bit in the RIGHT channel
				// then we're all done grabbing things, and should output
				// the new samples
				left_sample_out <= curr_left_sample;
				right_sample_out <= curr_right_sample;
				new_sample_out <= 1;
				curr_left_sample <= 0;
				curr_right_sample <= 0;
			end

			// save data to left or right channel depending on lrclk
			// on the falling edge of the BCLK
			// we only want to save the least significant 16 bits that come in
			// since we're storing in a 16 bit thing and shifting, this will do that
			if (!i2s_bclk_out && bit_counter <= 17) begin
				case (i2s_lrclk_out)
					// lrclk is 0 -> left transmitting
					// save current incoming bit in lsb, shift the rest
					0: curr_left_sample <= {curr_left_sample[14:0], i2s_data_in};
					// lrclk is 1 -> right transmitting
					1: curr_right_sample <= {curr_right_sample[14:0], i2s_data_in};
				endcase
			end
		end else begin
			// every one of the non-bclk-transition clock cycles
			new_sample_out <= 0; // make new_sample_out a pulse
			clk_counter <= clk_counter + 1; // increment
		end
	end
endmodule
