`timescale 1ns / 1ps

module NLMS(
    input logic clk_in,
    input logic rst_in,
    input logic ready_in,
    input logic signed [15:0] error_in,
    input logic signed [31:0] norm_in, 
    input logic signed [15:0] sample_in [63:0],
    input logic [5:0] offset_in,
    output logic signed [9:0] coeffs_out [63:0],
    output logic done
    );
    
    logic signed [55:0] term; // gradient descent step value
    logic signed [23:0] num; // numerator which will be divided
    
    // divider module for calculating the gradient step
    // dividend is num and divisor is norm
    div_gen_0 divide(.s_axis_dividend_tdata(num),
                    .s_axis_divisor_tdata(norm_in),
                    .s_axis_divisor_tvalid(ready_in), .s_axis_dividend_tvalid(ready_in),
                       .m_axis_dout_tdata(term), .m_axis_dout_tvalid(valid_out),
                       .aclk(clk_in));
                       
                       
    parameter ARRAY_SIZE = 64; //size of sample/coeffs array
    
    logic signed [34:0] temp_coeffs [63:0]; //intermediate coefficient variables to store maximum update information
    
    //real coefficients are assigned to first 10 bits of temp_coeffs
    always_comb begin
        num = error_in;
        for (int k = 0; k < ARRAY_SIZE; k++) coeffs_out[k] = temp_coeffs[k][34:25];
    end
        
    //update filter weights
    always_ff @(posedge clk_in) begin
        //if rst_in, reset coefficients
        if (rst_in) begin
            for(int i = 0; i < ARRAY_SIZE; i++) temp_coeffs[i] <= 35'd0;
            done <= 0;
        end else begin
            //if ready for LMS computation (term has been calculated in divider module)
            // then update all 64 coefficients using gradient descent approximation
            if (valid_out) begin
                    for (int k = 0; k < ARRAY_SIZE; k++) begin
                        if (offset_in >= k) temp_coeffs[k] <= temp_coeffs[k] + ((term*sample_in[offset_in-k]));
                        if (offset_in < k) temp_coeffs[k] <= temp_coeffs[k] + ((term*sample_in[64+offset_in-k]));
                    end
                    done <= 1;
            end else begin
                done <= 0;
            end
        end
    end
endmodule
