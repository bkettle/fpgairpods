`timescale 1ns / 1ps

module top_level(
    input logic clk_in,
    input logic rst_in,
    input logic ready_in,
    input logic signed [15:0] x_in,
    output logic signed [15:0] y_out
    );
    
//    logic signed [15:0] real_y_out;
    
//    assign real_y_out = y_out[25:10];
    
    logic signed [15:0] sample [255:0]; //buffer to hold samples
    logic [7:0] offset; //stores offset for reading from sample buffer
    logic signed [15:0] error; //stores most recent error calculated
    logic signed [9:0] coeffs [255:0]; //holds filter coefficients
    logic lms_done; //signals whether LMS is done updating weights
    
    //initialize sample buffer instance
    sampler sampler_buffer(.clk_in(clk_in),
                           .rst_in(rst_in),
                           .ready_in(ready_in),
                           .signal_in(1680+x_in),
                           .sample_out(sample),
                           .offset(offset));
    
    //initialize error calculator instance
    error_calculator find_error(.feedback_in(1680+x_in+y_out),//[25:10]),
                                .error_out(error),
                                .clk_in(clk_in));
    
    //initialize LMS instance
    LMS lms1(.clk_in(clk_in), 
             .rst_in(rst_in),
             .ready_in(ready_in),
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
