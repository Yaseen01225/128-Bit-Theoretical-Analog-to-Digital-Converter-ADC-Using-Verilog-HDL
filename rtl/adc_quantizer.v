
`timescale 1ns / 1ps
// Define the simulation time unit as 1 ns and the time precision as 1 ps.

// ============================================================================
// Project   : 128-Bit Theoretical Analog-to-Digital Converter (ADC)
// Module    : adc_quantizer
// Developer: Ghulam Yaseen Nangraj
// Platform  : Xilinx Vivado 2025.2.1
// HDL       : Verilog HDL (IEEE 1364)
//
// Purpose:
//   Convert a digitally represented fixed-point voltage into a 128-bit
//   unsigned digital code using combinational quantization logic.
//
// Input representation:
//   voltage_q16 represents voltage scaled by 2^16.
//   Actual modeled voltage = voltage_q16 / 65536 volts.
//
//   0      -> 0.00 V
//   16384  -> 0.25 V
//   32768  -> 0.50 V
//   49152  -> 0.75 V
//   65536  -> 1.00 V
//
// Quantization behavior:
//   - Zero input produces an all-zero output.
//   - Full-scale and overrange inputs produce an all-ones output.
//   - Intermediate inputs are mapped to a 128-bit digital code.
//
// IMPORTANT:
//   This is a theoretical digital model, not a physical 128-bit-precision ADC.
//   The input is a digital voltage representation, not an analog electrical pin.
// ============================================================================

module adc_quantizer (

    // 17-bit unsigned fixed-point voltage input.
    // The additional bit allows the input to represent 65536, corresponding
    // to exactly 1.00 V in the chosen scaling convention.
    input wire [16:0] voltage_q16,

    // 128-bit unsigned quantized output code.
    // Declared as reg because it is assigned inside an always procedural block.
    output reg [127:0] adc_code

);

    // ------------------------------------------------------------------------
    // Combinational quantization logic
    // ------------------------------------------------------------------------
    // The @* sensitivity list automatically includes signals read in this
    // block. Changes to voltage_q16 trigger reevaluation of the output.
    // No clock is required because this module is combinational.
    always @* begin

        // Case 1: Zero voltage.
        // Explicitly return zero so the output is exactly 128'b0.
        if (voltage_q16 == 17'd0) begin
            adc_code = 128'd0;

        // Case 2: Full-scale or overrange input.
        // 17'd65536 represents 1.00 V.
        // Saturation prevents the output from exceeding its maximum code.
        // {128{1'b1}} replicates logic 1 exactly 128 times.
        end else if (voltage_q16 >= 17'd65536) begin
            adc_code = {128{1'b1}};

        // Case 3: Intermediate input voltage.
        // For values 1 through 65535, construct a wide value by placing
        // the 16-bit input in the most significant 16 bits and appending
        // 112 zeros. This is equivalent to voltage_q16 * 2^112.
        end else begin

            // Subtract one to implement the selected mapping:
            // adc_code = (voltage_q16 * 2^112) - 1.
            // This yields a 128-bit code for intermediate input values.
            adc_code = {voltage_q16[15:0], 112'b0} - 128'd1;

        end

    end

endmodule
