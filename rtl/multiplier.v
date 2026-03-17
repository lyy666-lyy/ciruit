// =============================================================================
// Module: multiplier
// Description: 16-bit multiplier supporting both signed and unsigned modes.
//              mode=0: unsigned multiplication -> 32-bit unsigned product
//              mode=1: signed multiplication   -> 32-bit signed product
// =============================================================================

module multiplier (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire        mode,   // 0: unsigned, 1: signed
    output wire [31:0] product
);

    wire signed [16:0] a_ext;  // 17-bit sign-extended operand
    wire signed [16:0] b_ext;  // 17-bit sign-extended operand
    wire signed [33:0] product_full; // 34-bit full product

    // In unsigned mode, extend with 0; in signed mode, sign-extend
    assign a_ext = mode ? {a[15], a} : {1'b0, a};
    assign b_ext = mode ? {b[15], b} : {1'b0, b};

    // Signed multiplication (handles both signed and unsigned via extension)
    assign product_full = a_ext * b_ext;

    // Take lower 32 bits as result
    assign product = product_full[31:0];

endmodule
