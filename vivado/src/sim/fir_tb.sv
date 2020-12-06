`default_nettype none    // catch typos!
`timescale 1ns / 100ps 

// test fir31 module
// input samples are read from fir31.samples
// output samples are written to fir31.output
module fir_tb();
  logic clk,reset,ready;	// fir31 signals
  logic signed [15:0] x;
  logic signed [15:0] y;
  logic [20:0] scount;    // keep track of which sample we're at
  logic [6:0] cycle;      // wait 64 clocks between samples
  integer fin,fout,code;

	// fir coefficients
	logic signed [9:0] coeffs1 [63:0]; //holds filter coefficients
	logic signed [9:0] coeffs2 [63:0]; //holds filter coefficients
	logic use_second_coeffs; // 1 when coeffs2 should be used

  initial begin
    // open input/output files
    //CHANGE THESE TO ACTUAL FILE NAMES!YOU MUST DO THIS
    //fin = $fopen("sine2_10bits.waveform","r");
    //fin = $fopen("sine_148_7bits.waveform","r");
    //fin = $fopen("ila_test_input.waveform","r");
    fin = $fopen("impulse_128.waveform","r");
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
		use_second_coeffs = 0;
    x = 0;
    reset = 1;
    #10
    reset = 0;
		#39000
		use_second_coeffs = 1;
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

	logic signed [15:0] sample [63:0]; //buffer to hold samples
	logic [5:0] offset; //stores offset for reading from sample buffer
	logic signed [15:0] error; //stores most recent error calculated
	logic lms_done; //signals whether LMS is done updating weights
	logic signed [31:0] norm;


	initial begin
		// assign coeffs
		for (int i=0; i<64; i++) begin
			coeffs1[i] = i;
			coeffs2[i] = 2*i;
		end
	end
 
	sampler sampler_buffer(.clk_in(clk),
												 .rst_in(reset),
												 .norm_out(norm),
												 .ready_in(ready),
												 .signal_in(x),
												 .sample_out(sample),
												 .offset(offset)
											 );

	logic fir_done;
	fir63 fir_filter(.clk_in(clk),
									 .rst_in(reset),
									 .ready_in(ready),
									 .sample(sample),
									 .offset(offset),
									 .weights_in(use_second_coeffs ? coeffs1 : coeffs2),
									 .signal_out(y),
									 .done_out(fir_done)
	);

endmodule
