`timescale 1ns / 1ps

module error_calculator(
    input signed [15:0] feedback_in,
    input clk_in,
    input logic nc_on,
    output logic signed [15:0] error_out 
    );
    
    always_comb begin
        if (nc_on) begin
            error_out = 0 - feedback_in;
        end else begin
            error_out = 0;
        end
    end
endmodule