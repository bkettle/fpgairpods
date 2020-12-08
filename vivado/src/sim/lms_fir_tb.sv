`default_nettype none    // catch typos!
`timescale 1ns / 100ps 

//test ability of NLMS and FIR to cancel input signal
module lms_fir_tb();
  logic clk,reset,ready;	// clock, reset, ready signals
  logic signed [15:0] x;
  logic signed [15:0] y;
  logic [20:0] scount;    // keep track of which sample we're at
  logic [6:0] cycle;      // wait 128 clocks between samples
  integer fin,fout,code;

  initial begin
    // open input/output files
    fin = $fopen("ila_plane_input.waveform","r"); //conduct test on waveform extracted from ILA
    fout = $fopen("fir31.output","w");
    if (fin == 0 || fout == 0) begin
      $display("can't open file...");
      $stop;
    end

    // initialize state, assert reset for one clock cycle
    scount = 0;
    clk = 0;
    cycle = 0;
    ready = 0;
    x = 0;
    reset = 1;
    #10
    reset = 0;
  end

  // clk has 50% duty cycle, 10ns period
  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (cycle == 7'd127) begin
      // assert ready next cycle, read next sample from file
      ready <= 1;
      code = $fscanf(fin,"%d",x);
      // if we reach the end of the input file, we're done
      if (code != 1) begin
        $fclose(fout);
        $stop;
      end
    end
    else begin
      ready <= 0;
    end

    if (ready) begin
      // starting with sample 64, record results in output file
      if (scount > 63) $fdisplay(fout,"%d",y);
      scount <= scount + 1;
    end

    cycle <= cycle+1;
  end

  lms_tester_top_level dut(.clk_in(clk),.rst_in(reset),.ready_in(ready),
            .x_in(x),.y_out(y));

endmodule
