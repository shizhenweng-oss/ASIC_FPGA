`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// top.sv
// DE1-SoC board top-level wrapper.
// - CLOCK_50: FPGA 50 MHz clock
// - KEY[0]: reset button (active-low)
// - LEDR: status display
// -----------------------------------------------------------------------------
module top (
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,
    output logic [9:0]  LEDR
);

    logic        done;
    logic [31:0] cycles;

    // KEY[0] is active-low on DE1-SoC
    logic rst_n;
    assign rst_n = KEY[0];

    de1soc_wrapper #(
        .WIDTH(240),
        .HEIGHT(240),
        .INIT_FILE("image.mif")
    ) u_wrap (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .done(done),
        .total_cycles(cycles)
    );

    // LEDs:
    // LEDR[0] = done
    // LEDR[9:1] = some bits of cycles so it visibly toggles during run
    always_comb begin
        LEDR        = '0;
        LEDR[0]     = done;
        LEDR[9:1]   = cycles[24:16]; // pick any slice you like
    end

endmodule
