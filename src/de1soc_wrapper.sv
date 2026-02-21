`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// de1soc_wrapper.sv
// Thin wrapper around sobel_full_system.
// Exposes done + total_cycles for board-level (top.sv) display or later Avalon.
// -----------------------------------------------------------------------------
module de1soc_wrapper #(
    parameter int WIDTH  = 240,
    parameter int HEIGHT = 240,
    parameter string INIT_FILE = "image.mif"
)(
    input  logic        clk,
    input  logic        rst_n,          // active-low reset (common at board top)
    output logic        done,
    output logic [31:0] total_cycles
);

    // sobel_full_system expects active-high rst
    logic rst;
    assign rst = ~rst_n;

    sobel_full_system #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .TOTAL(WIDTH*HEIGHT),
        .INIT_FILE(INIT_FILE)
    ) u_sobel (
        .clk(clk),
        .rst(rst),
        .done(done),
        .total_cycles_out(total_cycles)
    );

endmodule
