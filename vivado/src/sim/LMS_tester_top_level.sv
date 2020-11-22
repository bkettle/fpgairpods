`timescale 1ns / 1ps

module lms_tester_top_level(
    input logic clk_in,
    input logic rst_in,
    input logic ready_in,
    input logic signed [15:0] x_in,
    output logic signed [15:0] y_out
    );
    
//    logic signed [15:0] real_y_out;
    
//    assign real_y_out = y_out[25:10];
//

    logic signed [15:0] sample [63:0]; //buffer to hold samples
    logic [5:0] offset; //stores offset for reading from sample buffer
    logic signed [15:0] error; //stores most recent error calculated
    logic signed [9:0] coeffs [63:0]; //holds filter coefficients
    logic lms_done; //signals whether LMS is done updating weights
    logic signed [31:0] norm;
    
    logic lowpass_done;
    logic [15:0] lowpass_out;
    //initialize lowpass instance
    lowpass lp_filter(.clk_in(clk_in),
                      .rst_in(rst_in),
                      .ready_in(ready_in),
                      .done_out(lowpass_done),
                      .signal_in(x_in),
                      .signal_out(lowpass_out));
    
    //initialize sample buffer instance
    sampler sampler_buffer(.clk_in(clk_in),
                           .rst_in(rst_in),
                           .norm_out(norm),
                           .ready_in(lowpass_done),
                           .signal_in(lowpass_out),
                           .sample_out(sample),
                           .offset(offset));
    
		logic cup_sim_done;
		logic signed [15:0] cup_sim_feedback;
		logic signed [7:0] trimmed_speaker_output;
		assign trimmed_speaker_output = y_out[8:1];
		//cup_simulator cup_sim(.clk_in(clk_in),
		//											.reset_in(rst_in),
		//											.ready_in(lowpass_done),
		//											.done_out(cup_sim_done),
		//											.ambient_sample_in(lowpass_out),
		//											.speaker_output_in(trimmed_speaker_output),
		//											.feedback_sample_out(cup_sim_feedback)
		//											);

    //initialize error calculator instance
		logic signed [15:0] sim_feedback;
		assign sim_feedback = lowpass_out + y_out;
    error_calculator find_error(.feedback_in(sim_feedback),//[25:10]),
                                .error_out(error),
                                .nc_on(1),
                                .clk_in(clk_in)
															);
    
    //initialize LMS instance
    NLMS nlms1(.clk_in(clk_in), 
             .rst_in(rst_in),
             .ready_in(lowpass_done),
             .error_in(error),
             .norm_in(norm),
             .sample_in(sample),
             .offset_in(offset),
             .coeffs_out(coeffs),
             .done(lms_done));
    
    //initialize FIR Filter instance
		logic fir_done;
    fir63 fir_filter(.clk_in(clk_in),
                     .rst_in(rst_in),
                     .ready_in(lms_done),
                     .sample(sample),
                     .offset(offset),
                     .weights_in(coeffs),
                     .signal_out(y_out),
										 .done_out(fir_done)
		);
    
endmodule
