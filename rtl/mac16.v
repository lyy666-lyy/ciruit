// =============================================================================
// Module: mac16
// Description: 16-bit Multiply-Accumulate (MAC16) top-level module.
//
//   Architecture:
//     Input A[15:0], B[15:0] -> Multiplier -> 32-bit product
//     Product + Accumulator -> Adder -> 32-bit sum + carry
//     Sum -> Accumulator Register -> out_31[31:0]
//
//   Signals:
//     a[15:0]   - 16-bit input operand A
//     b[15:0]   - 16-bit input operand B
//     clk       - Clock signal
//     rst_n     - Asynchronous active-low reset
//     en        - Enable signal (high to compute)
//     mode      - 0: unsigned MAC; 1: signed (two's complement) MAC
//     out_31    - 32-bit accumulated output
//     carry     - Overflow/carry flag
//     out_ready - Output valid flag
//
//   Target frequency: >= 500MHz
// =============================================================================

module mac16 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire        mode,
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [31:0] out_31,
    output wire        carry,
    output wire        out_ready
);

    // =========================================================================
    // Internal wires
    // =========================================================================
    wire [31:0] mult_product;   // Multiplier output
    wire [31:0] add_sum;        // Adder output
    wire        add_carry;      // Adder carry/overflow
    wire [31:0] acc_value;      // Current accumulator value (feedback)

    // =========================================================================
    // Stage 1: Multiplier (combinational)
    //   Computes a * b, supporting signed/unsigned via mode
    // =========================================================================
    multiplier u_multiplier (
        .a       (a),
        .b       (b),
        .mode    (mode),
        .product (mult_product)
    );

    // =========================================================================
    // Stage 2: Adder (combinational)
    //   Adds multiplier product to current accumulator value
    // =========================================================================
    adder u_adder (
        .product   (mult_product),
        .acc_in    (acc_value),
        .mode      (mode),
        .sum       (add_sum),
        .carry_out (add_carry)
    );

    // =========================================================================
    // Stage 3: Accumulator Register (sequential)
    //   Stores the running accumulated result
    // =========================================================================
    accumulator u_accumulator (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (en),
        .sum_in    (add_sum),
        .carry_in  (add_carry),
        .acc_out   (acc_value),
        .carry_out (carry),
        .out_ready (out_ready)
    );

    // Output is the accumulator value
    assign out_31 = acc_value;

endmodule
