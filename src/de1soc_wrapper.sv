`timescale 1ns/100ps

module de1soc_wrapper (
    input         CLOCK_50,
    input  [9:0]  SW,
    input  [3:0]  KEY,

    inout         PS2_CLK,
    inout         PS2_DAT,

    output [6:0]  HEX5,
    output [6:0]  HEX4,
    output [6:0]  HEX3,
    output [6:0]  HEX2,
    output [6:0]  HEX1,
    output [6:0]  HEX0,

    output [9:0]  LEDR,

    output [7:0]  VGA_R,
    output [7:0]  VGA_G,
    output [7:0]  VGA_B,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_BLANK_N,
    output        VGA_SYNC_N,
    output        VGA_CLK
);

    // KEY[0] is typically active-low on DE1-SoC
    logic rst;
    assign rst = ~KEY[0];

    logic done;
    logic [31:0] cycles;

    // Instantiate your simulation-friendly top
    top u_top (
        .clk(CLOCK_50),
        .rst(rst),
        .done(done),
        .total_cycles_out(cycles)
    );

    // Debug LEDs
    assign LEDR[0]   = done;
    assign LEDR[9:1] = cycles[8:0];

    // HEX displays off (active-low)
    assign HEX0 = 7'b1111111;
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;

    // VGA black/inactive
    assign VGA_R = 8'b0;
    assign VGA_G = 8'b0;
    assign VGA_B = 8'b0;
    assign VGA_HS      = 1'b1;
    assign VGA_VS      = 1'b1;
    assign VGA_BLANK_N = 1'b1;
    assign VGA_SYNC_N  = 1'b0;
    assign VGA_CLK     = CLOCK_50;

endmodule
