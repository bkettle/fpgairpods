`timescale 1ns / 1ps

module error_calculator(
    input signed [15:0] feedback_in,
    input clk_in,
    input logic nc_on,
    input logic error_ready,
    input logic rst_in,
    input logic signed [7:0] error_high_in,
    input logic signed [7:0] error_low_in,
    output logic signed [15:0] error_out,
    output logic error_locked_out,
    output logic done_out
    );
    
    parameter CONVERGED_SIZE = 256;
    logic [255:0] converged; //all zeros when last 32 feedback samples are within target range
    assign error_locked_out = converged == 0;
    
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            for (int i = 0; i < CONVERGED_SIZE; i++) converged[i] <= 1;
        end else if (error_ready) begin
            if (converged > 0) converged <= {converged[CONVERGED_SIZE-2:0], ~((error_low_in<feedback_in)&&(feedback_in<error_high_in))};
            
            if (nc_on && (converged > 0)) begin
                error_out <= 0 - feedback_in;
            end else begin
                error_out <= 0;
            end
            
            done_out <= 1;
        end else done_out <= 0;
    end
endmodule