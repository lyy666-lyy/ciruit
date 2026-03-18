// =============================================================================
// Module: adder
// Description: 32-bit signed adder with overflow detection.
//              Adds the 32-bit signed multiplication product to the 32-bit
//              signed accumulator value, producing a 32-bit sum and an
//              overflow flag.
// =============================================================================

module adder (
    input  wire [31:0] product,     // From multiplier (signed)
    input  wire [31:0] acc_in,      // Current accumulator value (signed)
    output wire [31:0] sum,         // Addition result
    output wire        overflow     // Signed overflow flag
);

    // Sign-extend to 33 bits for overflow detection
    wire [32:0] product_ext = {product[31], product};
    wire [32:0] acc_ext     = {acc_in[31],  acc_in};
    wire [32:0] result_ext  = product_ext + acc_ext;

    assign sum = result_ext[31:0];

    // Signed overflow: two same-sign operands produce a different-sign result
    assign overflow = (product[31] == acc_in[31]) && (sum[31] != product[31]);

endmodule
