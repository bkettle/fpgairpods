`timescale 1ns / 1ps

module cup_simulator(
		input clk_in,
		input reset_in,
		input ready_in,
		output logic done_out,
		input signed [15:0] ambient_sample_in,
		input signed [7:0] speaker_output_in,
		output logic signed [15:0] feedback_sample_out
  );

	parameter SAMPLE_DELAY = 6;

	logic signed [15:0] ambient_history [63:0];
	logic [5:0] ambient_history_offset;

	logic signed [15:0] shifted_speaker_output;
	assign shifted_speaker_output = speaker_output_in <<< 8;

	logic signed [15:0] next_sample;
	always_comb begin
		next_sample = ambient_history_offset < SAMPLE_DELAY ?
			ambient_history[64 + ambient_history_offset - SAMPLE_DELAY] :
			ambient_history[ambient_history_offset - SAMPLE_DELAY]; 
	end

	always_ff @(posedge clk_in) begin
		if (reset_in) begin
			ambient_history_offset <= 0;
			feedback_sample_out <= 1;
			for (int i=0; i<64; i++)
				ambient_history[i] <= 1; // clear all values
		end else if (ready_in) begin
			ambient_history[ambient_history_offset] <= ambient_sample_in;
			ambient_history_offset <= ambient_history_offset + 1;
			// should multiply ambient sample by some fraction to simulate passive
			// cancellation in the future
			feedback_sample_out <= shifted_speaker_output + 
				ambient_history[ambient_history_offset - SAMPLE_DELAY];
			done_out <= 1;
		end else done_out <= 0;
	end
endmodule
