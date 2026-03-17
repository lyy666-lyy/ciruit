// =============================================================================
// Testbench: tb_mac16
// Description: Comprehensive testbench for MAC16 module.
//   Test cases:
//     1. Reset functionality
//     2. Unsigned MAC (mode=0) - basic cases
//     3. Signed MAC (mode=1) - positive * positive
//     4. Signed MAC (mode=1) - negative * positive
//     5. Signed MAC (mode=1) - negative * negative
//     6. Boundary values (max, min, zero)
//     7. Enable control (en toggling)
//     8. Continuous accumulation (multiple MAC cycles)
//     9. Mode switching mid-operation
//    10. Overflow/carry detection
// =============================================================================

`timescale 1ns / 1ps

module tb_mac16;

    // =========================================================================
    // Signals
    // =========================================================================
    reg         clk;
    reg         rst_n;
    reg         en;
    reg         mode;
    reg  [15:0] a;
    reg  [15:0] b;
    wire [31:0] out_31;
    wire        carry;
    wire        out_ready;

    // Test tracking
    integer test_num;
    integer pass_count;
    integer fail_count;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    mac16 u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (en),
        .mode      (mode),
        .a         (a),
        .b         (b),
        .out_31    (out_31),
        .carry     (carry),
        .out_ready (out_ready)
    );

    // =========================================================================
    // Clock generation: 500MHz -> 2ns period
    // =========================================================================
    initial clk = 0;
    always #1 clk = ~clk;  // 2ns period = 500MHz

    // =========================================================================
    // Helper tasks
    // =========================================================================
    task reset;
        begin
            rst_n = 0;
            en    = 0;
            mode  = 0;
            a     = 0;
            b     = 0;
            @(posedge clk);
            @(posedge clk);
            rst_n = 1;
            @(posedge clk);
        end
    endtask

    task mac_op(
        input [15:0] in_a,
        input [15:0] in_b,
        input        in_mode,
        input        in_en
    );
        begin
            @(negedge clk);
            a    = in_a;
            b    = in_b;
            mode = in_mode;
            en   = in_en;
            @(posedge clk);
            #0.1; // Small delay for output to settle
        end
    endtask

    task check_result(
        input [31:0] expected_out,
        input        expected_ready,
        input [255:0] test_name
    );
        begin
            if (out_31 !== expected_out || out_ready !== expected_ready) begin
                $display("FAIL [Test %0d] %0s: out_31=%h (expected %h), out_ready=%b (expected %b)",
                         test_num, test_name, out_31, expected_out, out_ready, expected_ready);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [Test %0d] %0s: out_31=%h, carry=%b, out_ready=%b",
                         test_num, test_name, out_31, carry, out_ready);
                pass_count = pass_count + 1;
            end
            test_num = test_num + 1;
        end
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        // Setup waveform dump
        $dumpfile("mac16_wave.vcd");
        $dumpvars(0, tb_mac16);

        test_num   = 1;
        pass_count = 0;
        fail_count = 0;

        $display("==========================================================");
        $display("  MAC16 Testbench - Starting Tests");
        $display("==========================================================");

        // =================================================================
        // Test 1: Reset functionality
        // =================================================================
        $display("\n--- Test Group 1: Reset ---");
        reset;
        check_result(32'h0, 1'b0, "Reset clears output");

        // =================================================================
        // Test 2: Unsigned MAC basic - 3 * 5 = 15
        // =================================================================
        $display("\n--- Test Group 2: Unsigned MAC Basic ---");
        reset;
        mac_op(16'd3, 16'd5, 1'b0, 1'b1);
        // After 1 clock: acc = 0 + 3*5 = 15
        @(posedge clk); #0.1;
        check_result(32'd15, 1'b1, "Unsigned 3*5=15");

        // =================================================================
        // Test 3: Unsigned MAC accumulation - accumulate 3*5 + 7*8 = 15 + 56 = 71
        // =================================================================
        $display("\n--- Test Group 3: Unsigned Accumulation ---");
        reset;
        mac_op(16'd3, 16'd5, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        // acc = 15
        mac_op(16'd7, 16'd8, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        // acc = 15 + 56 = 71
        check_result(32'd71, 1'b1, "Unsigned 3*5+7*8=71");

        // =================================================================
        // Test 4: Signed MAC - positive * positive: 100 * 200 = 20000
        // =================================================================
        $display("\n--- Test Group 4: Signed pos*pos ---");
        reset;
        mac_op(16'd100, 16'd200, 1'b1, 1'b1);
        @(posedge clk); #0.1;
        check_result(32'd20000, 1'b1, "Signed 100*200=20000");

        // =================================================================
        // Test 5: Signed MAC - negative * positive: (-3) * 5 = -15
        // =================================================================
        $display("\n--- Test Group 5: Signed neg*pos ---");
        reset;
        // -3 in 16-bit two's complement = 0xFFFD
        mac_op(16'hFFFD, 16'd5, 1'b1, 1'b1);
        @(posedge clk); #0.1;
        // -15 in 32-bit two's complement = 0xFFFFFFF1
        check_result(32'hFFFFFFF1, 1'b1, "Signed (-3)*5=-15");

        // =================================================================
        // Test 6: Signed MAC - negative * negative: (-3) * (-5) = 15
        // =================================================================
        $display("\n--- Test Group 6: Signed neg*neg ---");
        reset;
        // -3 = 0xFFFD, -5 = 0xFFFB
        mac_op(16'hFFFD, 16'hFFFB, 1'b1, 1'b1);
        @(posedge clk); #0.1;
        check_result(32'd15, 1'b1, "Signed (-3)*(-5)=15");

        // =================================================================
        // Test 7: Signed MAC - positive * negative: 5 * (-3) = -15
        // =================================================================
        $display("\n--- Test Group 7: Signed pos*neg ---");
        reset;
        mac_op(16'd5, 16'hFFFD, 1'b1, 1'b1);
        @(posedge clk); #0.1;
        check_result(32'hFFFFFFF1, 1'b1, "Signed 5*(-3)=-15");

        // =================================================================
        // Test 8: Boundary - zero inputs
        // =================================================================
        $display("\n--- Test Group 8: Zero inputs ---");
        reset;
        mac_op(16'd0, 16'd12345, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        check_result(32'd0, 1'b1, "Unsigned 0*12345=0");

        // =================================================================
        // Test 9: Boundary - max unsigned: 65535 * 65535 = 4294836225
        // =================================================================
        $display("\n--- Test Group 9: Max unsigned ---");
        reset;
        mac_op(16'hFFFF, 16'hFFFF, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        // 65535 * 65535 = 0xFFFE0001
        check_result(32'hFFFE0001, 1'b1, "Unsigned 65535*65535");

        // =================================================================
        // Test 10: Boundary - max signed positive: 32767 * 32767 = 1073676289
        // =================================================================
        $display("\n--- Test Group 10: Max signed positive ---");
        reset;
        mac_op(16'h7FFF, 16'h7FFF, 1'b1, 1'b1);
        @(posedge clk); #0.1;
        // 32767 * 32767 = 0x3FFF0001
        check_result(32'h3FFF0001, 1'b1, "Signed 32767*32767");

        // =================================================================
        // Test 11: Boundary - min signed: (-32768) * (-32768) = 1073741824
        // =================================================================
        $display("\n--- Test Group 11: Min signed * min signed ---");
        reset;
        mac_op(16'h8000, 16'h8000, 1'b1, 1'b1);
        @(posedge clk); #0.1;
        // (-32768) * (-32768) = 1073741824 = 0x40000000
        check_result(32'h40000000, 1'b1, "Signed (-32768)*(-32768)");

        // =================================================================
        // Test 12: Boundary - min signed * max signed: (-32768) * 32767 = -1073709056
        // =================================================================
        $display("\n--- Test Group 12: Min signed * max signed ---");
        reset;
        mac_op(16'h8000, 16'h7FFF, 1'b1, 1'b1);
        @(posedge clk); #0.1;
        // (-32768) * 32767 = -1073709056 = 0xC0008000
        check_result(32'hC0008000, 1'b1, "Signed (-32768)*32767");

        // =================================================================
        // Test 13: Enable control - en=0 should not update accumulator
        // =================================================================
        $display("\n--- Test Group 13: Enable control ---");
        reset;
        // First: enable and accumulate 10*10 = 100
        mac_op(16'd10, 16'd10, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        check_result(32'd100, 1'b1, "en=1: 10*10=100");

        // Now: disable and try 20*20 -> should NOT update
        mac_op(16'd20, 16'd20, 1'b0, 1'b0);
        @(posedge clk); #0.1;
        check_result(32'd100, 1'b0, "en=0: stays 100");

        // Re-enable: accumulate 5*5 = 25 -> total = 125
        mac_op(16'd5, 16'd5, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        check_result(32'd125, 1'b1, "en=1: 100+5*5=125");

        // =================================================================
        // Test 14: Multi-cycle accumulation (unsigned)
        // =================================================================
        $display("\n--- Test Group 14: Multi-cycle unsigned accumulation ---");
        reset;
        // Accumulate: 1*1 + 2*2 + 3*3 + 4*4 + 5*5 = 1+4+9+16+25 = 55
        mac_op(16'd1, 16'd1, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        mac_op(16'd2, 16'd2, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        mac_op(16'd3, 16'd3, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        mac_op(16'd4, 16'd4, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        mac_op(16'd5, 16'd5, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        check_result(32'd55, 1'b1, "Sum of squares 1..5=55");

        // =================================================================
        // Test 15: Multi-cycle accumulation (signed, mixed)
        // =================================================================
        $display("\n--- Test Group 15: Multi-cycle signed accumulation ---");
        reset;
        // Accumulate: (-2)*3 + 4*(-5) + 6*7 = -6 + (-20) + 42 = 16
        mac_op(16'hFFFE, 16'd3, 1'b1, 1'b1);    // -2 * 3 = -6
        @(posedge clk); #0.1;
        mac_op(16'd4, 16'hFFFB, 1'b1, 1'b1);    // 4 * (-5) = -20
        @(posedge clk); #0.1;
        mac_op(16'd6, 16'd7, 1'b1, 1'b1);       // 6 * 7 = 42
        @(posedge clk); #0.1;
        // -6 + (-20) + 42 = 16
        check_result(32'd16, 1'b1, "Signed mixed acc=16");

        // =================================================================
        // Test 16: Unsigned overflow/carry test
        // =================================================================
        $display("\n--- Test Group 16: Unsigned overflow ---");
        reset;
        // 65535 * 65535 = 0xFFFE0001, then add another 65535*65535
        mac_op(16'hFFFF, 16'hFFFF, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        mac_op(16'hFFFF, 16'hFFFF, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        // 0xFFFE0001 + 0xFFFE0001 = 0x1FFFC0002 -> lower 32 = 0xFFFC0002, carry=1
        $display("INFO [Test %0d] Unsigned overflow: out_31=%h, carry=%b, out_ready=%b",
                 test_num, out_31, carry, out_ready);
        if (carry == 1'b1) begin
            $display("PASS [Test %0d] Unsigned carry detected", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [Test %0d] Unsigned carry NOT detected", test_num);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;

        // =================================================================
        // Test 17: Reset during operation
        // =================================================================
        $display("\n--- Test Group 17: Reset during operation ---");
        mac_op(16'd100, 16'd100, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        // Now reset mid-operation
        rst_n = 0;
        @(posedge clk); #0.1;
        check_result(32'd0, 1'b0, "Reset clears mid-op");
        rst_n = 1;
        @(posedge clk);

        // =================================================================
        // Test 18: Signed accumulation to negative then back to positive
        // =================================================================
        $display("\n--- Test Group 18: Signed acc neg->pos ---");
        reset;
        // (-100) * 50 = -5000
        mac_op(16'hFF9C, 16'd50, 1'b1, 1'b1);  // -100 * 50
        @(posedge clk); #0.1;
        // -5000 in 32-bit = 0xFFFFEC78
        check_result(32'hFFFFEC78, 1'b1, "Signed -100*50=-5000");

        // Now add 200 * 50 = 10000 -> total = -5000 + 10000 = 5000
        mac_op(16'd200, 16'd50, 1'b1, 1'b1);
        @(posedge clk); #0.1;
        check_result(32'd5000, 1'b1, "Signed -5000+200*50=5000");

        // =================================================================
        // Test 19: One operand is 1 (identity test)
        // =================================================================
        $display("\n--- Test Group 19: Identity multiplication ---");
        reset;
        mac_op(16'd12345, 16'd1, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        check_result(32'd12345, 1'b1, "Unsigned 12345*1=12345");

        // =================================================================
        // Test 20: Both operands are 1
        // =================================================================
        $display("\n--- Test Group 20: 1*1 ---");
        reset;
        mac_op(16'd1, 16'd1, 1'b0, 1'b1);
        @(posedge clk); #0.1;
        check_result(32'd1, 1'b1, "Unsigned 1*1=1");

        // =================================================================
        // Summary
        // =================================================================
        $display("\n==========================================================");
        $display("  MAC16 Testbench - Summary");
        $display("  Total: %0d | Passed: %0d | Failed: %0d",
                 pass_count + fail_count, pass_count, fail_count);
        $display("==========================================================");

        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** SOME TESTS FAILED ***");

        $display("==========================================================\n");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
