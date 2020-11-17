`timescale 1ns / 1ps

module add(
    input logic signed [15:0] antinoise_in,
    input logic signed [15:0] music_in,
    output logic signed [15:0] digital_signal_out
    );
    
    always_comb begin
        digital_signal_out = antinoise_in + music_in;
    end
endmodule
