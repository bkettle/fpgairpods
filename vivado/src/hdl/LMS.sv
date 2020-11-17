`timescale 1ns / 1ps

module LMS(
    input logic clk_in,
    input logic rst_in,
    input logic ready_in,
    input logic signed [15:0] error_in,
    input logic signed [15:0] sample_in [63:0],
    input logic [5:0] offset_in,
    output logic signed [9:0] coeffs_out [63:0],
    output logic done
    );
    
    parameter ARRAY_SIZE = 64; //size of sample/coeffs array
    
    logic [34:0] temp_coeffs [63:0]; //intermediate coefficient variables to store maximum update information
    
    //real coefficients are assigned to first 10 bits of temp_coeffs
    always_comb begin
        for (int k = 0; k < ARRAY_SIZE; k++) coeffs_out[k] = temp_coeffs[k][34:25];
    end
        
    //update filter weights
    always_ff @(posedge clk_in) begin
        //if rst_in, reset coefficients
        if (rst_in) begin
            for(int i = 0; i < ARRAY_SIZE; i++) temp_coeffs[i] <= 35'd67108864;
            done <= 0;
        end else begin
            //if ready for LMS computation, update all 64 coefficients using gradient descent approximation
            if (ready_in) begin
                    for (int k = 0; k < ARRAY_SIZE; k++) begin
                        if (offset_in >= k) temp_coeffs[k] <= temp_coeffs[k] + ((error_in[15:13]*sample_in[offset_in-k]));
                        if (offset_in < k) temp_coeffs[k] <= temp_coeffs[k] + ((error_in[15:13]*sample_in[64+offset_in-k]));
                    end
                    done <= 1;
            end else begin
                done <= 0;
            end
        end
    end
endmodule
