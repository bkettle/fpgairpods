`timescale 1ns / 1ps
module process_music(
		input [15:0] music_adc_in,
		output logic signed [15:0] music_sample_out
  );

	always_comb begin
		// center the audio signal, it was biased around .5v, so shift down
		music_sample_out = music_adc_in - 32767;
	end
endmodule
