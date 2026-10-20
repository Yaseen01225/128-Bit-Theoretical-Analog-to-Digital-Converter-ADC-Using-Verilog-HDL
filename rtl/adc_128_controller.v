
`timescale 1ns / 1ps
// Define the simulation time unit as 1 ns and precision as 1 ps.

// ============================================================================
// Project   : 128-Bit Theoretical Analog-to-Digital Converter (ADC)
// Module    : adc_128_controller
// Developer : Ghulam Yaseen Nangraj
// Platform  : Xilinx Vivado 2025.2.1
// HDL       : Verilog HDL (IEEE 1364)
//
// Purpose:
//   Control the conversion handshake, capture the quantized result, and
//   generate status signals using a synchronous finite-state machine (FSM).
//
// Handshake operation:
//   1. In ST_IDLE, the controller waits for start to be asserted.
//   2. When start is sampled high on a rising clock edge, busy is asserted.
//   3. The controller enters ST_CONVERT.
//   4. On the next rising clock edge, quantized_code is captured into
//      result_data, busy is cleared, and done is asserted.
//   5. The controller returns to ST_IDLE and can accept another request.
//
// Reset:
//   rst is synchronous and active-high. It takes effect on a rising edge.
//
// IMPORTANT:
//   This controller manages a behavioral quantizer. It does not implement
//   physical analog sampling or a real 128-bit conversion process.
// ============================================================================

module adc_128_controller (

    // System clock: all controller state and registered outputs update
    // on the rising edge of this signal.
    input wire clk,

    // Synchronous, active-high reset.
    // When sampled high at a rising edge, it clears the FSM and outputs.
    input wire rst,

    // Conversion request.
    // The controller accepts start only when it is in the IDLE state.
    input wire start,

    // 128-bit quantized code produced by the adc_quantizer module.
    // This value is captured into result_data in the CONVERT state.
    input wire [127:0] quantized_code,

    // Registered 128-bit conversion result.
    // Holds its previous value between conversions and is cleared by reset.
    output reg [127:0] result_data,

    // Conversion status.
    // High while the controller is waiting to capture the quantized result.
    output reg busy,

    // Completion indicator.
    // Asserted for one clock cycle when result_data is captured.
    output reg done

);

    // ------------------------------------------------------------------------
    // FSM state definitions
    // ------------------------------------------------------------------------

    // ST_IDLE: no conversion request is currently being processed.
    // A start request can be accepted in this state.
    localparam ST_IDLE = 1'b0;

    // ST_CONVERT: the controller captures the quantized result on the
    // next rising clock edge and then returns to ST_IDLE.
    localparam ST_CONVERT = 1'b1;

    // One-bit register holding the current FSM state.
    // It changes only on a rising clock edge.
    reg state;

    // ------------------------------------------------------------------------
    // Synchronous sequential logic
    // ------------------------------------------------------------------------
    // The entire FSM and its registered outputs are updated on the rising
    // edge of clk. Nonblocking assignments (<=) model clocked registers.
    always @(posedge clk) begin

        // --------------------------------------------------------------------
        // Synchronous reset
        // --------------------------------------------------------------------
        // Reset has priority over all normal state-machine operations.
        if (rst) begin

            // Return the FSM to its idle state.
            state <= ST_IDLE;

            // Clear the stored conversion result.
            result_data <= 128'd0;

            // Indicate that no conversion is active.
            busy <= 1'b0;

            // Ensure that no completion pulse is active during reset.
            done <= 1'b0;

        end else begin

            // ----------------------------------------------------------------
            // Default completion behavior
            // ----------------------------------------------------------------
            // Clear done on every normal clock edge by default.
            // The CONVERT state overrides this assignment to produce a
            // one-clock-cycle completion pulse.
            done <= 1'b0;

            // Select the action according to the current FSM state.
            case (state)

                // ------------------------------------------------------------
                // STATE 1: IDLE
                // ------------------------------------------------------------
                ST_IDLE: begin

                    // No conversion is being processed while idle.
                    busy <= 1'b0;

                    // Accept a new request when start is sampled high.
                    if (start) begin

                        // Mark the conversion as active.
                        busy <= 1'b1;

                        // Advance to the conversion-result capture state.
                        state <= ST_CONVERT;

                    end

                    // If start is low, the state remains ST_IDLE.
                    // The previous result_data value is retained because
                    // no new assignment to result_data is made here.
                end

                // ------------------------------------------------------------
                // STATE 2: CONVERT
                // ------------------------------------------------------------
                ST_CONVERT: begin

                    // Capture the 128-bit code supplied by the quantizer.
                    // This assignment updates result_data after the clock edge.
                    result_data <= quantized_code;

                    // The result has been captured, so clear the busy flag.
                    busy <= 1'b0;

                    // Assert done to indicate that the result is available.
                    // This pulse lasts until the next rising edge, unless reset
                    // is asserted.
                    done <= 1'b1;

                    // Return to IDLE so the next conversion can be requested.
                    state <= ST_IDLE;

                end

                // ------------------------------------------------------------
                // DEFAULT / RECOVERY STATE
                // ------------------------------------------------------------
                // Handle an unexpected or invalid state value by restoring
                // the controller to a known idle condition.
                default: begin

                    // Recover the state machine to IDLE.
                    state <= ST_IDLE;

                    // Clear the stored result for a known recovery value.
                    result_data <= 128'd0;

                    // Clear the conversion-in-progress indicator.
                    busy <= 1'b0;

                    // Do not report a completed conversion during recovery.
                    done <= 1'b0;

                end

            endcase

        end

    end

// End of the synchronous ADC controller module.
endmodule
