`timescale 1ns / 1ps

module error_calculator(
    input signed [15:0] feedback_in,
    input clk_in,
    input logic nc_on,
    input logic error_ready,
    input logic rst_in,
    input logic signed [7:0] lock_high_in,
    input logic signed [7:0] lock_low_in,
    input logic signed [15:0] unlock_low_in,
    input logic signed [15:0] unlock_high_in,
    input logic unlockable,
    output logic signed [15:0] error_out,
    output logic error_locked_out,
    output logic done_out
    );
    
    parameter CONVERGED_SIZE = 256;
    logic [255:0] converged; //all zeros when last 256 feedback samples are within target range
    logic [255:0] error_bad; //all zeros when the last 256 feedbcak samples are within safe range
    assign error_locked_out = converged == 0;
    
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            for (int i = 0; i < CONVERGED_SIZE; i++) begin
                converged[i] <= 1;
                error_bad[i] <= 1;
            end
        end else if (error_ready) begin
            if ((converged > 0) || ((error_bad > 0)&&unlockable)) 
                converged <= {converged[CONVERGED_SIZE-2:0], ~((lock_low_in<feedback_in)&&(feedback_in<lock_high_in))};
            
            error_bad <= {error_bad[CONVERGED_SIZE-2:0], ~((unlock_low_in<feedback_in)&&(feedback_in<unlock_high_in))};
            
            if (nc_on && (converged > 0)) begin
                error_out <= 0 - feedback_in;
            end else begin
                error_out <= 0;
            end
            
            done_out <= 1;
        end else done_out <= 0;
    end
endmodule