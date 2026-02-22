// ============================================================================
// DE1-SoC / Quartus-ready: 240x240 streaming Sobel (8-bit grayscale)
// - Reads input image from ROM initialized by a .mif file (image.mif)
// - Builds a 3x3 window using 2 line buffers (on-chip RAM inference)
// - Computes Sobel magnitude (|Gx| + |Gy| approx) with 1-stage pipeline
// - Writes ONLY valid Sobel pixels into on-chip RAM (binary bytes)
//   Output size = (WIDTH-2)*(HEIGHT-2) bytes
//
// HOW TO USE IN QUARTUS (important):
// 1) Put this file in your project (e.g., sobel_full_system.sv)
// 2) Put "image.mif" in the SAME project directory
// 3) Add image.mif to the Quartus project files (Project -> Add/Remove Files)
// 4) Set top-level entity to top (if you use top.sv) OR sobel_full_system (if no wrapper)
//
// Notes:
// - This is synthesizable RTL (no testbench).
// - output_mem is internal FPGA RAM. To read it from HPS, you must add an
//   Avalon-MM interface or use Platform Designer memory mapping (not included).
// ============================================================================

`timescale 1ns/1ps

// ============================================================================
// 1) 3x3 Window Generator (streaming raster scan, WIDTH pixels per row)
// ============================================================================
module window_3x3 #(
    parameter int WIDTH = 240
)(
    input  logic       clk,
    input  logic [7:0] pixel_in,

    output logic [7:0] p0, p1, p2,
    output logic [7:0] p3, p4, p5,
    output logic [7:0] p6, p7, p8,

    output logic       valid_out
);

    (* ramstyle = "M10K" *) logic [7:0] line1 [0:WIDTH-1]; // previous row
    (* ramstyle = "M10K" *) logic [7:0] line2 [0:WIDTH-1]; // row before previous

    logic [$clog2(WIDTH)-1:0] x;
    logic [31:0]              y;

    logic [7:0] row1_pix;
    logic [7:0] row0_pix;

    logic [7:0] r0c0, r0c1, r0c2;
    logic [7:0] r1c0, r1c1, r1c2;
    logic [7:0] r2c0, r2c1, r2c2;

    logic valid_now;

    always_ff @(posedge clk) begin
        // read old values before overwrite
        row1_pix <= line1[x];
        row0_pix <= line2[x];

        // shift line buffers
        line2[x] <= line1[x];
        line1[x] <= pixel_in;

        // shift window columns
        r0c0 <= r0c1;   r0c1 <= r0c2;   r0c2 <= row0_pix;
        r1c0 <= r1c1;   r1c1 <= r1c2;   r1c2 <= row1_pix;
        r2c0 <= r2c1;   r2c1 <= r2c2;   r2c2 <= pixel_in;

        // raster counters
        if (x == WIDTH-1) begin
            x <= '0;
            y <= y + 1;
        end else begin
            x <= x + 1;
        end

        valid_now <= (x >= 2) && (y >= 2);
        valid_out <= valid_now;

        // window outputs
        p0 <= r0c0; p1 <= r0c1; p2 <= r0c2;
        p3 <= r1c0; p4 <= r1c1; p5 <= r1c2;
        p6 <= r2c0; p7 <= r2c1; p8 <= r2c2;
    end

endmodule

// ============================================================================
// 2) Sobel Pipeline (1-stage pipelined)
// ============================================================================
module sobel_pipeline (
    input  logic clk,

    input  logic signed [7:0] p0, p1, p2,
    input  logic signed [7:0] p3, p4, p5,
    input  logic signed [7:0] p6, p7, p8,

    output logic [7:0] mag
);

    logic signed [11:0] gx, gy;
    logic [11:0] abs_gx, abs_gy;
    logic [12:0] sum_abs;

    function automatic [11:0] abs12(input logic signed [11:0] v);
        if (v[11]) abs12 = (~v) + 12'd1;
        else       abs12 = v;
    endfunction

    always_comb begin
        gx = ( $signed({4'd0,p2}) + ($signed({4'd0,p5}) <<< 1) + $signed({4'd0,p8}) )
           - ( $signed({4'd0,p0}) + ($signed({4'd0,p3}) <<< 1) + $signed({4'd0,p6}) );

        gy = ( $signed({4'd0,p6}) + ($signed({4'd0,p7}) <<< 1) + $signed({4'd0,p8}) )
           - ( $signed({4'd0,p0}) + ($signed({4'd0,p1}) <<< 1) + $signed({4'd0,p2}) );

        abs_gx  = abs12(gx);
        abs_gy  = abs12(gy);
        sum_abs = abs_gx + abs_gy;
    end

    always_ff @(posedge clk) begin
        if (sum_abs[12:8] != 0) mag <= 8'hFF;
        else                   mag <= sum_abs[7:0];
    end

endmodule

// ============================================================================
// 3) Streaming Sobel Top
// ============================================================================
module sobel_stream_top #(
    parameter int WIDTH = 240
)(
    input  logic       clk,
    input  logic [7:0] pixel_in,
    output logic [7:0] pixel_out,
    output logic       valid_out
);

    logic [7:0] p0,p1,p2,p3,p4,p5,p6,p7,p8;
    logic       win_valid;

    window_3x3 #(.WIDTH(WIDTH)) WIN (
        .clk(clk),
        .pixel_in(pixel_in),
        .p0(p0), .p1(p1), .p2(p2),
        .p3(p3), .p4(p4), .p5(p5),
        .p6(p6), .p7(p7), .p8(p8),
        .valid_out(win_valid)
    );

    sobel_pipeline SOB (
        .clk(clk),
        .p0($signed(p0)), .p1($signed(p1)), .p2($signed(p2)),
        .p3($signed(p3)), .p4($signed(p4)), .p5($signed(p5)),
        .p6($signed(p6)), .p7($signed(p7)), .p8($signed(p8)),
        .mag(pixel_out)
    );

    logic v_d1;
    always_ff @(posedge clk) v_d1 <= win_valid;
    assign valid_out = v_d1;

endmodule


module image_rom #(
    parameter int WIDTH  = 240,
    parameter int HEIGHT = 240,
    parameter int TOTAL  = WIDTH*HEIGHT
)(
    input  logic clk,
    input  logic [$clog2(TOTAL)-1:0] addr,
    output logic [7:0] pixel
);

    (* ramstyle = "M10K" *)
    (* init_file = "image.mif" *)
    logic [7:0] mem [0:TOTAL-1];

    always_ff @(posedge clk) begin
        pixel <= mem[addr];
    end

endmodule

// ============================================================================
// 5) Full System: ROM -> Sobel -> Output RAM
// ============================================================================
module sobel_full_system #(
    parameter int WIDTH  = 240,
    parameter int HEIGHT = 240,
    parameter int TOTAL  = WIDTH*HEIGHT,
    parameter string INIT_FILE = "image.mif"
)(
    input  logic       clk,
    input  logic       rst,
    output logic       done,
    output logic [31:0] total_cycles_out
);

    localparam int OUTW   = WIDTH - 2;
    localparam int OUTH   = HEIGHT - 2;
    localparam int OUTTOT = OUTW * OUTH;

    logic [$clog2(TOTAL)-1:0] read_addr;
    logic [7:0]               pixel_in;

    image_rom #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .TOTAL(TOTAL)
    ) IMAGE_MEM (
        .clk(clk),
        .addr(read_addr),
        .pixel(pixel_in)
    );

    logic [7:0] pixel_out;
    logic       valid_out;

    sobel_stream_top #(.WIDTH(WIDTH)) SOBEL_CORE (
        .clk(clk),
        .pixel_in(pixel_in),
        .pixel_out(pixel_out),
        .valid_out(valid_out)
    );

    (* ramstyle = "M10K" *) logic [7:0] output_mem [0:OUTTOT-1];

    logic [$clog2(TOTAL)-1:0]   in_count;
    logic [$clog2(OUTTOT)-1:0]  out_count;

    logic [31:0] total_cycles;

    always_ff @(posedge clk) begin
        if (rst) begin
            read_addr     <= '0;
            in_count      <= '0;
            out_count     <= '0;
            done          <= 1'b0;
            total_cycles  <= 32'd0;
        end else begin
            total_cycles <= total_cycles + 1;

            if (!done) begin
                // advance through ROM addresses
                if (in_count < TOTAL-1) begin
                    in_count  <= in_count + 1;
                    read_addr <= read_addr + 1;
                end

                // write only valid outputs
                if (valid_out) begin
                    output_mem[out_count] <= pixel_out;

                    if (out_count == OUTTOT-1) begin
                        done <= 1'b1;
                    end else begin
                        out_count <= out_count + 1;
                    end
                end
            end
        end
    end

    assign total_cycles_out = total_cycles;

endmodule
