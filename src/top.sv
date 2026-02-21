// src/top.sv
module top (
    input  logic clk,
    input  logic rst,
    output logic done,
    output logic [31:0] total_cycles_out
);
    sobel_full_system #(
        .WIDTH(240),
        .HEIGHT(240),
        .TOTAL(240*240),
        .INIT_FILE("image.mif")   // hardware init file
    ) u_sobel (
        .clk(clk),
        .rst(rst),
        .done(done),
        .total_cycles_out(total_cycles_out)
    );
endmodule
