// =============================================================================
// Testbench: tb_mac16
// Description: Testbench for MAC16 module, following the contest specification.
//
//   Required test cases from spec:
//     1. din_A=3,  din_B=5   -> acc=15
//     2. din_A=-3, din_B=-5  -> acc=15+15=30
//     3. din_A=3,  din_B=-5  -> acc=30-15=15
//     After en falls: mac_out=15, out_ready=1
//
//   Additional test cases:
//     - Reset functionality
//     - Enable control (en toggling, restart accumulation)
//     - Boundary values (max positive, min negative, zero)
//     - Overflow/carry detection
//     - Multi-round accumulation
// =============================================================================

`timescale 1ns / 1ps

module tb_mac16;

    // =========================================================================
    // Signals
    // =========================================================================
    reg         clk;
    reg         rst_n;
    reg         en;
    reg  [15:0] din_A;
    reg  [15:0] din_B;
    wire [31:0] mac_out;
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
        .din_A     (din_A),
        .din_B     (din_B),
        .mac_out   (mac_out),
        .carry     (carry),
        .out_ready (out_ready)
    );

    // =========================================================================
    // Clock generation: 100MHz -> 10ns period (for simulation convenience)
    // =========================================================================
    initial clk = 0;
    always #5 clk = ~clk;  // 10ns period

    // =========================================================================
    // Helper tasks
    // =========================================================================

    // Full reset: assert rst_n low for 2 cycles, then release
    task do_reset;
        begin
            rst_n = 0;
            en    = 0;
            din_A = 0;
            din_B = 0;
            @(posedge clk);
            @(posedge clk);
            rst_n = 1;
            @(posedge clk);
        end
    endtask

    // Drive inputs on negedge, wait for posedge to latch
    task drive_inputs(
        input [15:0] a,
        input [15:0] b,
        input        enable
    );
        begin
            @(negedge clk);
            din_A = a;
            din_B = b;
            en    = enable;
            @(posedge clk);
            #0.1;
        end
    endtask

    // Check mac_out value
    task check_mac_out(
        input [31:0]  expected,
        input [255:0] test_name
    );
        begin
            if (mac_out !== expected) begin
                $display("FAIL [Test %0d] %0s: mac_out=0x%08h (expected 0x%08h)",
                         test_num, test_name, mac_out, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [Test %0d] %0s: mac_out=0x%08h, carry=%b, out_ready=%b",
                         test_num, test_name, mac_out, carry, out_ready);
                pass_count = pass_count + 1;
            end
            test_num = test_num + 1;
        end
    endtask

    // Check out_ready flag
    task check_ready(
        input        expected,
        input [255:0] test_name
    );
        begin
            if (out_ready !== expected) begin
                $display("FAIL [Test %0d] %0s: out_ready=%b (expected %b)",
                         test_num, test_name, out_ready, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [Test %0d] %0s: out_ready=%b",
                         test_num, test_name, out_ready);
                pass_count = pass_count + 1;
            end
            test_num = test_num + 1;
        end
    endtask

    // Check internal accumulator via hierarchical reference
    task check_acc(
        input [31:0]  expected,
        input [255:0] test_name
    );
        begin
            if (u_dut.u_accumulator.acc_out !== expected) begin
                $display("FAIL [Test %0d] %0s: acc=0x%08h (expected 0x%08h)",
                         test_num, test_name, u_dut.u_accumulator.acc_out, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [Test %0d] %0s: acc=0x%08h",
                         test_num, test_name, u_dut.u_accumulator.acc_out);
                pass_count = pass_count + 1;
            end
            test_num = test_num + 1;
        end
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        $dumpfile("mac16_wave.vcd");
        $dumpvars(0, tb_mac16);

        test_num   = 1;
        pass_count = 0;
        fail_count = 0;

        $display("==========================================================");
        $display("  MAC16 Testbench - Starting Tests");
        $display("==========================================================");

        // =================================================================
        // Test Group 1: Reset functionality
        // =================================================================
        $display("\n--- Test Group 1: Reset ---");
        do_reset;
        check_mac_out(32'h0, "Reset: mac_out=0");
        check_ready(1'b0, "Reset: out_ready=0");

        // =================================================================
        // Test Group 2: Required test cases from specification
        //   Step 1: din_A=3,  din_B=5   -> acc = 0 + 3*5 = 15
        //   Step 2: din_A=-3, din_B=-5  -> acc = 15 + (-3)*(-5) = 30
        //   Step 3: din_A=3,  din_B=-5  -> acc = 30 + 3*(-5) = 15
        //   Step 4: en falls -> mac_out = 15, out_ready = 1
        // =================================================================
        $display("\n--- Test Group 2: Spec required test cases ---");
        do_reset;

        // Step 1: en=1, din_A=3, din_B=5
        drive_inputs(16'd3, 16'd5, 1'b1);
        @(posedge clk); #0.1;
        check_acc(32'd15, "Spec step1: acc=3*5=15");

        // Step 2: en=1, din_A=-3 (0xFFFD), din_B=-5 (0xFFFB)
        drive_inputs(16'hFFFD, 16'hFFFB, 1'b1);
        @(posedge clk); #0.1;
        check_acc(32'd30, "Spec step2: acc=15+15=30");

        // Step 3: en=1, din_A=3, din_B=-5 (0xFFFB)
        drive_inputs(16'd3, 16'hFFFB, 1'b1);
        @(posedge clk); #0.1;
        check_acc(32'd15, "Spec step3: acc=30-15=15");

        // Step 4: en falls to 0 -> mac_out captures 15, out_ready=1
        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        check_mac_out(32'd15, "Spec result: mac_out=15");
        check_ready(1'b1, "Spec result: out_ready=1");

        // Verify out_ready and mac_out hold while en=0
        @(posedge clk); #0.1;
        check_mac_out(32'd15, "Hold: mac_out=15");
        check_ready(1'b1, "Hold: out_ready=1");

        // =================================================================
        // Test Group 3: Enable control - restart accumulation
        //   After en goes HIGH again, acc starts from 0
        // =================================================================
        $display("\n--- Test Group 3: Enable restart ---");
        // en rises again -> new accumulation from zero
        drive_inputs(16'd10, 16'd10, 1'b1);
        @(posedge clk); #0.1;
        check_acc(32'd100, "Restart: acc=10*10=100");
        check_ready(1'b0, "Restart: out_ready=0");

        // Continue accumulating
        drive_inputs(16'd5, 16'd5, 1'b1);
        @(posedge clk); #0.1;
        check_acc(32'd125, "Continue: acc=100+25=125");

        // en falls -> mac_out=125
        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        check_mac_out(32'd125, "Result: mac_out=125");
        check_ready(1'b1, "Result: out_ready=1");

        // =================================================================
        // Test Group 4: Signed neg*pos
        // =================================================================
        $display("\n--- Test Group 4: Signed neg*pos ---");
        do_reset;
        // -100 * 50 = -5000
        drive_inputs(16'hFF9C, 16'd50, 1'b1);
        @(posedge clk); #0.1;
        // -5000 = 0xFFFFEC78
        check_acc(32'hFFFFEC78, "Signed: acc=(-100)*50=-5000");

        // Add 200*50 = 10000 -> acc = -5000+10000 = 5000
        drive_inputs(16'd200, 16'd50, 1'b1);
        @(posedge clk); #0.1;
        check_acc(32'd5000, "Signed: acc=-5000+10000=5000");

        // en falls
        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        check_mac_out(32'd5000, "Signed: mac_out=5000");

        // =================================================================
        // Test Group 5: Boundary - zero inputs
        // =================================================================
        $display("\n--- Test Group 5: Zero inputs ---");
        do_reset;
        drive_inputs(16'd0, 16'd12345, 1'b1);
        @(posedge clk); #0.1;
        check_acc(32'd0, "Zero: acc=0*12345=0");

        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        check_mac_out(32'd0, "Zero: mac_out=0");

        // =================================================================
        // Test Group 6: Boundary - max positive (32767 * 32767)
        // =================================================================
        $display("\n--- Test Group 6: Max positive ---");
        do_reset;
        drive_inputs(16'h7FFF, 16'h7FFF, 1'b1);
        @(posedge clk); #0.1;
        // 32767 * 32767 = 1073676289 = 0x3FFF0001
        check_acc(32'h3FFF0001, "Max pos: acc=32767*32767");

        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        check_mac_out(32'h3FFF0001, "Max pos: mac_out");

        // =================================================================
        // Test Group 7: Boundary - min negative (-32768 * -32768)
        // =================================================================
        $display("\n--- Test Group 7: Min neg * Min neg ---");
        do_reset;
        drive_inputs(16'h8000, 16'h8000, 1'b1);
        @(posedge clk); #0.1;
        // (-32768) * (-32768) = 1073741824 = 0x40000000
        check_acc(32'h40000000, "Min neg sq: acc=(-32768)^2");

        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        check_mac_out(32'h40000000, "Min neg sq: mac_out");

        // =================================================================
        // Test Group 8: Boundary - min * max (-32768 * 32767)
        // =================================================================
        $display("\n--- Test Group 8: Min neg * Max pos ---");
        do_reset;
        drive_inputs(16'h8000, 16'h7FFF, 1'b1);
        @(posedge clk); #0.1;
        // (-32768) * 32767 = -1073709056 = 0xC0008000
        check_acc(32'hC0008000, "Min*Max: acc=(-32768)*32767");

        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        check_mac_out(32'hC0008000, "Min*Max: mac_out");

        // =================================================================
        // Test Group 9: Multi-cycle signed accumulation
        //   (-2)*3 + 4*(-5) + 6*7 = -6 + (-20) + 42 = 16
        // =================================================================
        $display("\n--- Test Group 9: Multi-cycle signed mix ---");
        do_reset;
        drive_inputs(16'hFFFE, 16'd3, 1'b1);    // -2 * 3 = -6
        @(posedge clk); #0.1;
        check_acc(32'hFFFFFFFA, "Mix: acc=(-2)*3=-6");

        drive_inputs(16'd4, 16'hFFFB, 1'b1);    // 4 * (-5) = -20
        @(posedge clk); #0.1;
        // -6 + (-20) = -26 = 0xFFFFFFE6
        check_acc(32'hFFFFFFE6, "Mix: acc=-6+(-20)=-26");

        drive_inputs(16'd6, 16'd7, 1'b1);       // 6 * 7 = 42
        @(posedge clk); #0.1;
        // -26 + 42 = 16
        check_acc(32'd16, "Mix: acc=-26+42=16");

        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        check_mac_out(32'd16, "Mix: mac_out=16");
        check_ready(1'b1, "Mix: out_ready=1");

        // =================================================================
        // Test Group 10: Multi-cycle unsigned-range accumulation
        //   Sum of squares: 1^2+2^2+3^2+4^2+5^2 = 55
        // =================================================================
        $display("\n--- Test Group 10: Sum of squares ---");
        do_reset;
        drive_inputs(16'd1, 16'd1, 1'b1); @(posedge clk); #0.1;
        drive_inputs(16'd2, 16'd2, 1'b1); @(posedge clk); #0.1;
        drive_inputs(16'd3, 16'd3, 1'b1); @(posedge clk); #0.1;
        drive_inputs(16'd4, 16'd4, 1'b1); @(posedge clk); #0.1;
        drive_inputs(16'd5, 16'd5, 1'b1); @(posedge clk); #0.1;
        check_acc(32'd55, "SumSq: acc=1+4+9+16+25=55");

        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        check_mac_out(32'd55, "SumSq: mac_out=55");

        // =================================================================
        // Test Group 11: Overflow / carry detection
        //   32767*32767 = 0x3FFF0001, then again: 0x3FFF0001+0x3FFF0001
        //   = 0x7FFE0002 (no overflow). Then one more: overflow.
        // =================================================================
        $display("\n--- Test Group 11: Overflow detection ---");
        do_reset;
        drive_inputs(16'h7FFF, 16'h7FFF, 1'b1); @(posedge clk); #0.1;
        // acc = 0x3FFF0001
        drive_inputs(16'h7FFF, 16'h7FFF, 1'b1); @(posedge clk); #0.1;
        // acc = 0x3FFF0001 + 0x3FFF0001 = 0x7FFE0002 (positive, no overflow)
        drive_inputs(16'h7FFF, 16'h7FFF, 1'b1); @(posedge clk); #0.1;
        // acc = 0x7FFE0002 + 0x3FFF0001 = 0xBFFD0003 (overflowed! sign flipped)

        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        $display("INFO [Test %0d] Overflow test: mac_out=0x%08h, carry=%b",
                 test_num, mac_out, carry);
        if (carry == 1'b1) begin
            $display("PASS [Test %0d] Signed overflow: carry detected", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [Test %0d] Signed overflow: carry NOT detected", test_num);
            fail_count = fail_count + 1;
        end
        test_num = test_num + 1;

        // =================================================================
        // Test Group 12: Reset during operation
        // =================================================================
        $display("\n--- Test Group 12: Reset during operation ---");
        do_reset;
        drive_inputs(16'd100, 16'd100, 1'b1);
        @(posedge clk); #0.1;
        // acc = 10000
        rst_n = 0;
        @(posedge clk); #0.1;
        check_mac_out(32'd0, "Mid-reset: mac_out=0");
        check_ready(1'b0, "Mid-reset: out_ready=0");
        rst_n = 1;
        @(posedge clk);

        // =================================================================
        // Test Group 13: Identity multiplication
        // =================================================================
        $display("\n--- Test Group 13: Identity ---");
        do_reset;
        drive_inputs(16'd12345, 16'd1, 1'b1);
        @(posedge clk); #0.1;
        check_acc(32'd12345, "Identity: acc=12345*1=12345");

        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        check_mac_out(32'd12345, "Identity: mac_out=12345");

        // =================================================================
        // Test Group 14: Multiple en on/off rounds
        // =================================================================
        $display("\n--- Test Group 14: Multiple rounds ---");
        do_reset;

        // Round 1: 4*5=20
        drive_inputs(16'd4, 16'd5, 1'b1);
        @(posedge clk); #0.1;
        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        check_mac_out(32'd20, "Round1: mac_out=20");

        // Round 2: 6*7=42 (fresh accumulation)
        drive_inputs(16'd6, 16'd7, 1'b1);
        @(posedge clk); #0.1;
        check_acc(32'd42, "Round2: acc=42 (fresh)");
        drive_inputs(16'd0, 16'd0, 1'b0);
        @(posedge clk); #0.1;
        check_mac_out(32'd42, "Round2: mac_out=42");

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
        #200000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
