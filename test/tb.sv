`timescale 1ns/1ps

module tb;

    // Parameters must match DUT
    parameter WIDTH  = 240;
    parameter HEIGHT = 240;
    parameter TOTAL  = WIDTH*HEIGHT;
    parameter OUTW   = WIDTH - 2;
    parameter OUTH   = HEIGHT - 2;
    parameter OUTTOT = OUTW * OUTH;

    // Clock / Reset
    logic clk;
    logic rst;

    // DUT signals
    logic done;
    logic [31:0] total_cycles;

    // Instantiate DUT
    sobel_full_system #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .TOTAL(TOTAL),
        .INIT_FILE("image.mif")
    ) DUT (
        .clk(clk),
        .rst(rst),
        .done(done),
        .total_cycles_out(total_cycles)
    );

    // ================================
    // Clock Generation (50 MHz)
    // ================================
    initial clk = 0;
    always #10 clk = ~clk;   // 20ns period → 50MHz

    // ================================
    // Simulation Control
    // ================================
    integer i;
    integer outfile;
    real time_sec;
    
    initial begin
        $display("Starting Sobel Simulation...");

        rst = 1;
        #100;
        rst = 0;

        // Wait until processing finishes
        wait(done);

        $display("=================================");
        $display("Sobel Processing Complete");
        $display("Total Cycles: %d", total_cycles);

        // Compute time (for 50 MHz clock)
        time_sec = total_cycles / 50_000_000.0;
        $display("Total Time (seconds): %f", time_sec);
        $display("=================================");

        // ==========================================
        // Save output memory to file (binary hex)
        // ==========================================
        outfile = $fopen("sobel_output_sim.hex", "w");

        if (outfile == 0) begin
            $display("ERROR: Could not open output file.");
        end else begin
            for (i = 0; i < OUTTOT; i = i + 1) begin
                $fwrite(outfile, "%02x\n", DUT.output_mem[i]);
            end
            $fclose(outfile);
            $display("Output saved to sobel_output_sim.hex");
        end

        $stop;
    end

endmodule
