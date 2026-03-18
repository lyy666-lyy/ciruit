// =============================================================================
// Module: mac16
// Description: 16-bit Multiply-Accumulate (MAC16) top-level module.
//
//   Architecture:
//     din_A[15:0], din_B[15:0] -> Multiplier -> 32-bit signed product
//     Product + Accumulator    -> Adder      -> 32-bit sum + overflow
//     Sum -> Accumulator Register -> mac_out[31:0] (when en falls)
//
//   Behavior (per spec):
//     en=1: Multiplier and accumulator active, inputs are read each cycle.
//           acc = acc + din_A * din_B. out_ready = 0.
//     en 1->0: Computation done. mac_out captures acc value.
//              Accumulator clears to zero. out_ready goes HIGH.
//     en=0 (steady): mac_out holds last result, out_ready stays HIGH.
//     en 0->1: New accumulation starts from zero, out_ready goes LOW.
//
//   Signals:
//     din_A[15:0] - 16-bit signed input operand A
//     din_B[15:0] - 16-bit signed input operand B
//     clk         - Clock signal
//     rst_n       - Asynchronous active-low reset
//     en          - Enable signal
//     mac_out     - 32-bit accumulated output (valid when out_ready=1)
//     carry       - Overflow flag (sticky, HIGH if overflow occurred)
//     out_ready   - Output valid flag (HIGH when computation done)
// =============================================================================

module mac16 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire [15:0] din_A,
    input  wire [15:0] din_B,
    output wire [31:0] mac_out,
    output wire        carry,
    output wire        out_ready
);

    // =========================================================================
    // Internal wires
    // =========================================================================
    wire [31:0] mult_product;   // Multiplier output
    wire [31:0] add_sum;        // Adder output
    wire        add_overflow;   // Adder overflow flag
    wire [31:0] acc_value;      // Current accumulator value (feedback)

    // =========================================================================
    // Stage 1: Multiplier (combinational)
    //   Performs signed 16x16 -> 32-bit multiplication
    // =========================================================================
    multiplier u_multiplier (
        .a       (din_A),
        .b       (din_B),
        .product (mult_product)
    );

    // =========================================================================
    // Stage 2: Adder (combinational)
    //   Adds multiplier product to current accumulator value
    // =========================================================================
    adder u_adder (
        .product  (mult_product),
        .acc_in   (acc_value),
        .sum      (add_sum),
        .overflow (add_overflow)
    );

    // =========================================================================
    // Stage 3: Accumulator (sequential)
    //   Internal acc accumulates during en=1.
    //   On en falling edge: mac_out captures acc, acc clears.
    // =========================================================================
    accumulator u_accumulator (
        .clk         (clk),
        .rst_n       (rst_n),
        .en          (en),
        .sum_in      (add_sum),
        .overflow_in (add_overflow),
        .acc_out     (acc_value),
        .mac_out     (mac_out),
        .carry       (carry),
        .out_ready   (out_ready)
    );

endmodule
