// =============================================================================
// Module: accumulator
// Description: 32-bit accumulator with output register, async reset, and
//              enable-controlled behavior per spec:
//
//   en=1: Multiply-accumulate active. Each clock cycle acc += product.
//         out_ready is LOW during computation.
//   en 1->0 (falling edge): Computation ends.
//         - mac_out register captures current acc value.
//         - Internal acc clears to zero.
//         - out_ready goes HIGH, carry is captured.
//   en=0 (steady): mac_out holds last result, out_ready stays HIGH.
//   en 0->1 (rising edge): New accumulation starts from zero.
//         - out_ready goes LOW, carry clears.
// =============================================================================

module accumulator (
    input  wire        clk,
    input  wire        rst_n,       // Async active-low reset
    input  wire        en,          // Enable signal
    input  wire [31:0] sum_in,      // Sum from adder (product + acc)
    input  wire        overflow_in, // Overflow flag from adder
    output reg  [31:0] acc_out,     // Internal accumulator (feedback to adder)
    output reg  [31:0] mac_out,     // Output register (holds result when en=0)
    output reg         carry,       // Overflow flag (sticky during accumulation)
    output reg         out_ready    // Output valid flag
);

    reg en_d;  // Delayed en for edge detection

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out   <= 32'b0;
            mac_out   <= 32'b0;
            carry     <= 1'b0;
            out_ready <= 1'b0;
            en_d      <= 1'b0;
        end else begin
            en_d <= en;

            if (en) begin
                // ---------------------------------------------------------
                // Active accumulation: acc += product each clock cycle
                // ---------------------------------------------------------
                acc_out   <= sum_in;
                out_ready <= 1'b0;

                if (!en_d) begin
                    // Rising edge of en: new computation starts, clear carry
                    carry <= overflow_in;
                end else if (overflow_in) begin
                    // Sticky carry: once overflow occurs, stays HIGH
                    carry <= 1'b1;
                end
            end else if (en_d) begin
                // ---------------------------------------------------------
                // Falling edge of en: computation done
                // Capture result to output register, clear accumulator
                // ---------------------------------------------------------
                mac_out   <= acc_out;
                acc_out   <= 32'b0;
                out_ready <= 1'b1;
                // carry retains its accumulated value
            end
            // else: en=0 steady state -> hold mac_out, carry, out_ready
        end
    end

endmodule
