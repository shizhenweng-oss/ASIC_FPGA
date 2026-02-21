// test/tb.sv
`timescale 1ns/1ps

module tb;

  // Required by your repo to generate waveforms
  initial begin
    $dumpfile("sim_out/wave.vcd");
    $dumpvars(0, tb);
  end

  // -------------------------
  // Clock / Reset
  // -------------------------
  logic clk = 0;
  logic rst = 1;

  // 50 MHz clock -> 20 ns period
  always #10 clk = ~clk;

  // DUT outputs
  logic done;
  logic [31:0] total_cycles_out;

  // -------------------------
  // DUT
  // -------------------------
  // This assumes you have src/top.sv:
  // module top(input clk, input rst, output done, output [31:0] total_cycles_out);
  top dut (
    .clk(clk),
    .rst(rst),
    .done(done),
    .total_cycles_out(total_cycles_out)
  );

  // -------------------------
  // Run / Timeout control
  // -------------------------
  int cycles;

  initial begin
    // Hold reset for a few cycles
    repeat (10) @(posedge clk);
    rst <= 0;

    cycles = 0;

    // Wait until done or timeout
    while (!done && cycles < 2_000_000) begin
      @(posedge clk);
      cycles++;
    end

    if (!done) begin
      $display("FAIL: timeout waiting for done. cycles=%0d", cycles);
      $finish;
    end

    $display("DONE asserted. total_cycles_out=%0d, sim_cycles=%0d",
             total_cycles_out, cycles);

    // Give one extra cycle to settle
    @(posedge clk);

    // -------------------------
    // Save output_mem to file (SIMULATION ONLY)
    // -------------------------
    // Your sobel_full_system writes ONLY valid pixels:
    // OUTW=238, OUTH=238 => OUTTOT=56644
    int OUTW   = 240 - 2;
    int OUTH   = 240 - 2;
    int OUTTOT = OUTW * OUTH;

    integer f;
    int i;

    f = $fopen("sim_out/sobel_output.hex", "w");
    if (f == 0) begin
      $display("FAIL: could not open sim_out/sobel_output.hex");
      $finish;
    end

    // Access internal memory hierarchically:
    // top -> sobel_full_system instance name in top.sv must be u_sobel (or adjust below).
    //
    // If in your top.sv you instantiated as: sobel_full_system u_sobel (...);
    // then dut.u_sobel.output_mem[i] is correct.
    for (i = 0; i < OUTTOT; i++) begin
      $fdisplay(f, "%02x", dut.u_sobel.output_mem[i]);
    end
    $fclose(f);

    $display("Wrote sim_out/sobel_output.hex (%0d bytes)", OUTTOT);

    $finish;
  end

endmodule
