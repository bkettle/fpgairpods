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
    
    logic signed [15:0] sample [63:0]; //buffer to hold samples
    logic [5:0] offset; //stores offset for reading from sample buffer
    logic signed [15:0] error; //stores most recent error calculated
    logic signed [9:0] coeffs [63:0]; //holds filter coefficients
    logic lms_done; //signals whether LMS is done updating weights

		logic [15:0] dc_removed_x;
		logic dc_remover_done;
		remove_dc dc_remover(
			.clk_in(clk_in), 
			.reset_in(rst_in), 
			.ready_in(ready_in), 
			.signal_in(x_in), 
			.signal_out(dc_removed_x), 
			.done_out(dc_remover_done)
		);

		logic [15:0] filtered_x;
		logic lowpass_finished;
		lowpass lowpass(
			.clk_in(clk_in), 
			.rst_in(rst_in), 
			.ready_in(dc_remover_done), 
			.signal_in(dc_removed_x), 
			.signal_out(filtered_x), 
			.done_out(lowpass_finished)
		);
    
    logic lowpass_done;
    logic [15:0] lowpass_out;
    //initialize lowpass instance
    lowpass lp_filter(.clk_in(clk_in),
                      .rst_in(rst_in),
                      .ready_in(ready_in),
                      .done_out(lowpass_done),
                      .signal_in(1775+x_in),
                      .signal_out(lowpass_out));
    
    //initialize sample buffer instance
    sampler sampler_buffer(.clk_in(clk_in),
                           .rst_in(rst_in),
                           .ready_in(lowpass_done),
                           .signal_in(lowpass_out),
                           .sample_out(sample),
                           .offset(offset));
    
    //initialize error calculator instance
    error_calculator find_error(.feedback_in(lowpass_out+y_out),//[25:10]),
                                .error_out(error),
                                .nc_on(1),
                                .clk_in(clk_in));
    
    //initialize LMS instance
    LMS lms1(.clk_in(clk_in), 
             .rst_in(rst_in),
             .ready_in(lowpass_done),
             .error_in(error),
             .sample_in(sample),
             .offset_in(offset),
             .coeffs_out(coeffs),
             .done(lms_done));
    
    //initialize FIR Filter instance
    fir63 fir_filter(.clk_in(clk_in),
                     .rst_in(rst_in),
                     .ready_in(lms_done),
                     .sample(sample),
                     .offset(offset),
                     .weights_in(coeffs),
                     .signal_out(y_out));
    
endmodule
