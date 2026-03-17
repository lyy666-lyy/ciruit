// =============================================================================
// Module: accumulator
// Description: 32-bit accumulator register with async reset and enable.
//              Stores the running sum of multiply-accumulate operations.
//              Also registers the carry flag and generates out_ready.
// =============================================================================

module accumulator (
    input  wire        clk,
    input  wire        rst_n,      // Async active-low reset
    input  wire        en,         // Enable
    input  wire [31:0] sum_in,     // Sum from adder
    input  wire        carry_in,   // Carry from adder
    output reg  [31:0] acc_out,    // Accumulated result
    output reg         carry_out,  // Registered carry/overflow
    output reg         out_ready   // Output valid flag
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out   <= 32'b0;
            carry_out <= 1'b0;
            out_ready <= 1'b0;
        end else if (en) begin
            acc_out   <= sum_in;
            carry_out <= carry_in;
            out_ready <= 1'b1;
        end else begin
            out_ready <= 1'b0;
        end
    end

endmodule
