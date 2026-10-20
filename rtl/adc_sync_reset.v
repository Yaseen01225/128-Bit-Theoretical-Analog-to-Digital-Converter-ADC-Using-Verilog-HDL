
`timescale 1ns / 1ps

// ============================================================================
// Module Name : adc_sync_reset
// Project     : Theoretical 128-Bit ADC Simulation
// Developer   : Ghulam Yaseen Nangraj
// Platform    : Xilinx Vivado 2025.2.1 / Verilog HDL
// Purpose     : Synchronous active-high reset helper.
// Description : Monitors the reset signal on each rising edge of the clock.
//               The output reset_seen indicates whether reset was active
//               at the most recent rising clock edge.
// Note        : This is a reusable utility module. The ADC top-level design
//               handles its reset directly and does not require this helper.
// ============================================================================

// Specify the simulation time unit and time precision.
// 1ns is the time unit; 1ps is the simulation precision.
`timescale 1ns / 1ps

module adc_sync_reset (

    input  wire clk,         // Clock input; state updates on its rising edge.
    input  wire rst,         // Synchronous, active-high reset input.
    output reg  reset_seen   // High for one clock interval when rst was high
                             // at the most recent rising clock edge.

);

    // Sequential logic triggered by the rising edge of the clock.
    // Because reset is checked inside this block, it is synchronous.
    always @(posedge clk) begin

        // If reset is high at the rising clock edge,
        // record that reset has been observed.
        if (rst)
            reset_seen <= 1'b1;

        // Otherwise, clear the indicator at the rising clock edge.
        else
            reset_seen <= 1'b0;

    end

endmodule
