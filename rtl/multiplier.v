// =============================================================================
// Module: multiplier
// Description: 16-bit signed multiplier.
//              Performs two's complement multiplication of two 16-bit signed
//              operands, producing a 32-bit signed product.
// =============================================================================

module multiplier (
    input  wire signed [15:0] a,       // 16-bit signed operand A
    input  wire signed [15:0] b,       // 16-bit signed operand B
    output wire signed [31:0] product  // 32-bit signed product
);

    assign product = a * b;

endmodule
