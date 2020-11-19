`timescale 1ns / 1ps

module lowpass(
		input clk_in, rst_in, ready_in,
		output logic done_out,
		input signed [15:0] signal_in,
		output logic signed [15:0] signal_out
  );

	logic signed [15:0] sample [31:0];  // 32 element array each 8 bits wide
	logic [4:0] offset; // pointer to the last element inserted in sample 

	logic [4:0] index; // rel. to most recent sample, ie index 1 is prev sample 
	logic signed [9:0] curr_coeff; // will always hold current coeff
	coeffs31 coeffs(.index_in(index), .coeff_out(curr_coeff)); // lookup coeff

	logic signed [25:0] accumulator; // store running sum, size from given y_out size

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
			sample[offset] <= signal_in;

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
				done_out <= 1; // trigger done pulse
			end else index <= index + 1; // prepare to add the next value
		end else begin
			// not working, so the value in accumulator should be the last
			// result
			signal_out <= accumulator[25:10];
			done_out <= 0;
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
			// these are generated using python:
			// scipy.signal.firwin(31, 700, fs=65000)
			// for 700hz cutoff frequency
			// then scaled by 2**10 and rounded
			5'd0:	 coeff = 10'sd4;
			5'd1:	 coeff = 10'sd4;
			5'd2:	 coeff = 10'sd6;
			5'd3:	 coeff = 10'sd9;
			5'd4:	 coeff = 10'sd13;
			5'd5:	 coeff = 10'sd18;
			5'd6:	 coeff = 10'sd24;
			5'd7:	 coeff = 10'sd30;
			5'd8:	 coeff = 10'sd36;
			5'd9:	 coeff = 10'sd42;
			5'd10:	 coeff = 10'sd48;
			5'd11:	 coeff = 10'sd54;
			5'd12:	 coeff = 10'sd58;
			5'd13:	 coeff = 10'sd61;
			5'd14:	 coeff = 10'sd63;
			5'd15:	 coeff = 10'sd64;
			5'd16:	 coeff = 10'sd63;
			5'd17:	 coeff = 10'sd61;
			5'd18:	 coeff = 10'sd58;
			5'd19:	 coeff = 10'sd54;
			5'd20:	 coeff = 10'sd48;
			5'd21:	 coeff = 10'sd42;
			5'd22:	 coeff = 10'sd36;
			5'd23:	 coeff = 10'sd30;
			5'd24:	 coeff = 10'sd24;
			5'd25:	 coeff = 10'sd18;
			5'd26:	 coeff = 10'sd13;
			5'd27:	 coeff = 10'sd9;
			5'd28:	 coeff = 10'sd6;
			5'd29:	 coeff = 10'sd4;
			5'd30:	 coeff = 10'sd4;
      default: coeff = 10'hXXX;
    endcase
  end
endmodule
