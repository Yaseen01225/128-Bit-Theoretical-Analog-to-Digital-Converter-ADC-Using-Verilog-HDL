
`timescale 1ns / 1ps  // Set simulation time unit to 1 ns and time precision to 1 ps.

// ============================================================================
// Project   : 128-Bit Theoretical Analog-to-Digital Converter (ADC)
// Module    : adc_128_top
// Developer : Ghulam Yaseen Nangraj
// Platform  : Xilinx Vivado 2025.2.1
// HDL       : Verilog HDL (IEEE 1364)
// Purpose   : Integrate the quantizer and synchronous conversion controller
//             into a single top-level ADC simulation module.
//
// Operation :
//   1. Receive a digitally represented input voltage.
//   2. Convert the input voltage into a 128-bit quantized code.
//   3. Use the controller to manage conversion timing and status signals.
//   4. Present the registered digital result through adc_data.
//
// IMPORTANT:
// This is a theoretical digital simulation model, not a physical 128-bit
// precision ADC. The voltage input is a digital fixed-point representation,
// not an electrical analog input pin. Real analog conversion requires an
// external ADC or a suitable analog front end.
// ============================================================================

module adc_128_top (

    // Clock input: all sequential controller operations synchronize to
    // the rising edge of this clock.
    input wire clk,

    // Synchronous, active-high reset: when rst is high at a rising clock
    // edge, the controller clears its state, output register, busy, and done.
    input wire rst,

    // Start command: a high level sampled while the controller is idle
    // requests a new conversion.
    input wire start,

    // Fixed-point voltage input (17 bits):
    // 0      represents 0.00 V
    // 16384  represents 0.25 V
    // 32768  represents 0.50 V
    // 49152  represents 0.75 V
    // 65536  represents 1.00 V
    // This input is a digital model of voltage, scaled by 2^16.
    input wire [16:0] voltage_q16,

    // Registered 128-bit digital conversion result.
    // The controller updates this output when conversion completes and
    // holds the result until the next conversion or reset.
    output wire [127:0] adc_data,

    // Busy status: high while the controller is processing a conversion.
    output wire busy,

    // Done status: pulses high for one clock cycle when the result is captured.
    output wire done

);

    // Internal 128-bit wire carrying the quantizer's combinational result
    // to the conversion controller.
    wire [127:0] quantized_code;

    // ------------------------------------------------------------------------
    // Quantizer instance
    // ------------------------------------------------------------------------
    // U_QUANTIZER converts voltage_q16 into a 128-bit digital code.
    // This module performs the mathematical mapping and saturation handling.
    // Its output is combinational and is not itself the registered ADC result.
    adc_quantizer U_QUANTIZER (

        // Connect the top-level fixed-point voltage input to the quantizer.
        .voltage_q16 (voltage_q16),

        // Route the calculated 128-bit code to the internal signal.
        .adc_code    (quantized_code)

    );

    // ------------------------------------------------------------------------
    // Synchronous conversion controller instance
    // ------------------------------------------------------------------------
    // U_CONTROLLER manages the conversion handshake and output register.
    // It accepts start while idle, asserts busy during the conversion interval,
    // captures quantized_code, and generates a one-clock done pulse.
    adc_128_controller U_CONTROLLER (

        // Supply the shared system clock to the controller.
        .clk            (clk),

        // Supply the synchronous active-high reset.
        .rst            (rst),

        // Request a conversion through the controller's start input.
        .start          (start),

        // Provide the quantized value that the controller will capture.
        .quantized_code (quantized_code),

        // Connect the controller's registered result to the top-level output.
        .result_data    (adc_data),

        // Expose the controller's busy status at the top-level interface.
        .busy           (busy),

        // Expose the controller's conversion-complete pulse.
        .done           (done)

    );

// End of the top-level ADC module.
endmodule
