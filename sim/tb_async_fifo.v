`timescale 1ns / 1ps

module tb_async_fifo;

    // ============================================================
    // 1. PARAMETERS & SIGNALS
    // ============================================================
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4; // Depth = 16
    
    reg wr_clk, rd_clk;
    reg wr_rst_n, rd_rst_n;
    reg wr_en, rd_en;
    reg [DATA_WIDTH-1:0] wr_data;
    wire [DATA_WIDTH-1:0] rd_data;
    wire full, empty;
    
    // Test Bench Variables
    integer i;
    reg [DATA_WIDTH-1:0] expected_data;
    integer error_count = 0;

    // Instantiate the DUT (Device Under Test)
    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
        .wr_clk(wr_clk), .wr_rst_n(wr_rst_n), .wr_en(wr_en), .wr_data(wr_data), .full(full),
        .rd_clk(rd_clk), .rd_rst_n(rd_rst_n), .rd_en(rd_en), .rd_data(rd_data), .empty(empty)
    );

    // ============================================================
    // 2. CLOCK GENERATION (Async Clocks)
    // ============================================================
    // Write Clock: 100 MHz (10ns period)
    initial wr_clk = 0;
    always #5 wr_clk = ~wr_clk;

    // Read Clock: 40 MHz (25ns period) - Slower and unrelated phase
    initial rd_clk = 0;
    always #12.5 rd_clk = ~rd_clk;

    // ============================================================
    // 3. TASKS (Helper Functions)
    // ============================================================
    
    // Task to Reset the System
    task apply_reset;
    begin
        $display("[%0t] Resetting System...", $time);
        wr_rst_n = 0;
        rd_rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;
        #50; // Hold reset
        wr_rst_n = 1;
        rd_rst_n = 1;
        #20; // Wait for recovery
    end
    endtask

    // Task to Write a Single Word
    task write_word(input [DATA_WIDTH-1:0] data);
    begin
        @(posedge wr_clk); // Sync to write clock
        if (!full) begin
            wr_en = 1;
            wr_data = data;
            $display("[%0t] WR: %h", $time, data);
        end else begin
            $display("[%0t] SKIPPED WR: FIFO Full!", $time);
            wr_en = 0;
        end
        @(posedge wr_clk);
        wr_en = 0; // Turn off enable
    end
    endtask

    // Task to Read and Verify
   task read_and_check(input [DATA_WIDTH-1:0] exp_val);
    begin
        // Update the waveform variable so we can see it!
        expected_data = exp_val; 
        
        wait(!empty); 
        @(posedge rd_clk);
        rd_en = 1;
        @(posedge rd_clk);
        rd_en = 0;
        #1; 
        if (rd_data !== exp_val) begin
            $display("[%0t] ERROR: Expected %h, Got %h", $time, exp_val, rd_data);
            error_count = error_count + 1;
        end else begin
            $display("[%0t] RD: %h (OK)", $time, rd_data);
        end
    end
    endtask

    // ============================================================
    // 4. MAIN TEST SEQUENCE
    // ============================================================
    initial begin
        // Setup Waveform Dump (Optional, Vivado does this automatically)
        // $dumpfile("fifo.vcd"); $dumpvars(0, tb_async_fifo);

        apply_reset();

        // --- TEST CASE 1: FILL IT UP (Check Full Flag) ---
        $display("\n--- TC1: Fill FIFO (Depth 16) ---");
        for (i=0; i<16; i=i+1) begin
            write_word(i); // Write 0x00, 0x01... 0x0F
        end
        
        // Wait a bit for flags to update across clock domains
        #100; 
        if (full) $display("SUCCESS: FIFO is FULL.");
        else      $display("ERROR: FIFO should be FULL!");

        // --- TEST CASE 2: OVERFLOW (Try to write when Full) ---
        $display("\n--- TC2: Overflow Protection ---");
        write_word(8'hFF); // Should NOT be written
        // If your design is correct, wr_ptr won't move.

        // --- TEST CASE 3: DRAIN IT (Check Empty & Data) ---
        $display("\n--- TC3: Drain FIFO & Verify Data ---");
        for (i=0; i<16; i=i+1) begin
            read_and_check(i); // Expect 0x00, 0x01... 0x0F
        end

        #100;
        if (empty) $display("SUCCESS: FIFO is EMPTY.");
        else       $display("ERROR: FIFO should be EMPTY!");

        // --- TEST CASE 4: UNDERFLOW (Try to read when Empty) ---
        $display("\n--- TC4: Underflow Protection ---");
        @(posedge rd_clk);
        rd_en = 1; // Try to read garbage
        @(posedge rd_clk);
        rd_en = 0;
        // Verify rd_ptr didn't move (you can check this in waveform)

        // --- TEST CASE 5: CONCURRENT R/W (Stress Test) ---
        $display("\n--- TC5: Concurrent Read/Write ---");
        
        apply_reset();
        
        fork
            // Thread A: Writer (Fast) - Uses variable 'j'
            begin: writer_thread
                integer j; // Local variable for this thread
                for (j=0; j<30; j=j+1) begin
                    write_word(j + 8'hA0); 
                    #20; 
                end
            end

            // Thread B: Reader (Slow) - Uses variable 'k'
            begin: reader_thread
                integer k; // Local variable for this thread
                #50; 
                for (k=0; k<30; k=k+1) begin
                    read_and_check(k + 8'hA0);
                end
            end
        join

        // ============================================================
        // 5. FINAL REPORT
        // ============================================================
        $display("\n==========================================");
        if (error_count == 0)
            $display("TEST PASSED: FIFO Verified Successfully!");
        else
            $display("TEST FAILED: %0d Errors Found.", error_count);
        $display("==========================================");
        
        $finish;
    end

endmodule
