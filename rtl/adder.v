// =============================================================================
// Module: adder
// Description: 33-bit adder with carry output.
//              Adds the 32-bit multiplication product to the 32-bit accumulator
//              value, producing a 32-bit sum and a carry/overflow flag.
// =============================================================================

module adder (
    input  wire [31:0] product,     // From multiplier
    input  wire [31:0] acc_in,      // Current accumulator value
    input  wire        mode,        // 0: unsigned, 1: signed
    output wire [31:0] sum,         // Addition result
    output wire        carry_out    // Overflow/carry flag
);

    wire [32:0] result_ext;

    // Extend to 33 bits for carry/overflow detection
    // In unsigned mode: zero-extend; in signed mode: sign-extend
    wire [32:0] product_ext = mode ? {{1{product[31]}}, product} : {1'b0, product};
    wire [32:0] acc_ext     = mode ? {{1{acc_in[31]}},  acc_in}  : {1'b0, acc_in};

    assign result_ext = product_ext + acc_ext;
    assign sum        = result_ext[31:0];

    // Carry/overflow detection
    // Unsigned: carry is the 33rd bit
    // Signed: overflow when signs of inputs are same but result sign differs
    wire unsigned_carry = result_ext[32];
    wire signed_overflow = (product[31] == acc_in[31]) && (sum[31] != product[31]);

    assign carry_out = mode ? signed_overflow : unsigned_carry;

endmodule
