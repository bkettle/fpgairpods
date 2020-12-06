`timescale 1ns / 1ps

module error_calculator(
    input signed [15:0] feedback_in,
    input clk_in,
    input logic nc_on,
    input logic error_ready,
    input logic rst_in,
    output logic signed [15:0] error_out,
    output logic done_out
    );
    
    parameter CONVERGED_SIZE = 256;
    logic [255:0] converged; //all zeros when last 32 feedback samples are within target range
    
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            for (int i = 0; i < CONVERGED_SIZE; i++) converged[i] <= 1;
        end else if (error_ready) begin
            if (converged > 0) converged <= {converged[CONVERGED_SIZE-2:0], ~((-10<feedback_in)&&(feedback_in<10))};
            
            if (nc_on && (converged > 0)) begin
                error_out <= 0 - feedback_in;
            end else begin
                error_out <= 0;
            end
            
            done_out <= 1;
        end else done_out <= 0;
    end
endmodule