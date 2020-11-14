`timescale 1ns / 1ps

module error_calculator(
    input signed [15:0] feedback_in,
    output logic signed [15:0] error_out 
    );
    
    always_comb begin
        error_out = feedback_in;
    end
endmodule
