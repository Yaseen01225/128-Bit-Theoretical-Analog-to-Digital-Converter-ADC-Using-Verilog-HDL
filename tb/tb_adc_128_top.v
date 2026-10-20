`timescale 1ns / 1ps
// ============================================================================
// Project   : 128-Bit Theoretical Analog-to-Digital Converter (ADC)
// Module    : tb_adc_128_top
// Developer : Ghulam Yaseen Nangraj
// Simulator : Xilinx Vivado v2025.2.1
// HDL       : Verilog HDL (IEEE 1364)
//
// Purpose:
//   Verify the theoretical ADC model by sweeping the input voltage upward
//   from 0 V to 1 V in 0.25 V steps, then downward from 1 V back to 0 V.
//   Each sample is converted and checked against its expected 128-bit code.
//
// Voltage encoding:
//   The input is an unsigned Q16-scaled voltage value:
//       voltage_q16 = voltage_in_volts * 65536
//   Therefore, one input count represents 1/65536 of a volt.
//   0 V    -> 0
//   0.25 V -> 16384
//   0.50 V -> 32768
//   0.75 V -> 49152
//   1.00 V -> 65536
//
// IMPORTANT:
//   This testbench supplies digital fixed-point samples. It does not measure
//   a real analog voltage or prove physical 128-bit ADC accuracy.
// ============================================================================

module tb_adc_128_top;

    // ------------------------------------------------------------------------
    // Signals driven by this testbench
    // ------------------------------------------------------------------------
    reg clk;                  // Simulation clock; toggles every 5 ns.
    reg rst;                  // Synchronous, active-high reset for the DUT.
    reg start;                // Requests a conversion when the DUT is idle.
    reg [16:0] voltage_q16;   // Input voltage represented in Q16-scaled form.

    // ------------------------------------------------------------------------
    // Signals observed from the Device Under Test (DUT)
    // ------------------------------------------------------------------------
    wire [127:0] adc_data;    // Registered 128-bit conversion result.
    wire busy;                // High while the controller is converting.
    wire done;                // Completion indicator, expected to pulse for
                              // one clock cycle after a conversion finishes.

    // ------------------------------------------------------------------------
    // Testbench bookkeeping
    // ------------------------------------------------------------------------
    integer pass_count;       // Number of checks that passed.
    integer fail_count;       // Number of checks that failed.

    // Temporary snapshot of adc_data, used to verify that the output remains
    // unchanged when no new conversion is requested.
    reg [127:0] held_data;

    // ------------------------------------------------------------------------
    // Device Under Test (DUT)
    // Instantiate the complete ADC design and connect all top-level signals.
    // ------------------------------------------------------------------------
    adc_128_top DUT (
        .clk         (clk),
        .rst         (rst),
        .start       (start),
        .voltage_q16 (voltage_q16),
        .adc_data    (adc_data),
        .busy        (busy),
        .done        (done)
    );

    // ------------------------------------------------------------------------
    // Clock generation
    // Start the clock low, then invert it every 5 ns. The full period is
    // 10 ns, corresponding to a simulation clock frequency of 100 MHz.
    // ------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Task: report_pass
    // Print a PASS message and increment the successful-check counter.
    // The input argument supplies the descriptive name of the check.
    // ------------------------------------------------------------------------
    task report_pass;
        input [255:0] name;
        begin
            $display("PASS: %0s", name);
            pass_count = pass_count + 1;
        end
    endtask

    // ------------------------------------------------------------------------
    // Task: report_fail
    // Print a FAIL message and increment the failed-check counter.
    // The input argument supplies the descriptive name of the check.
    // ------------------------------------------------------------------------
    task report_fail;
        input [255:0] name;
        begin
            $display("FAIL: %0s", name);
            fail_count = fail_count + 1;
        end
    endtask

    // ------------------------------------------------------------------------
    // Task: check_conversion
    // Purpose:
    //   1. Apply one voltage sample away from the active clock edge.
    //   2. Assert start long enough for the DUT to sample the request.
    //   3. Wait for done, with a timeout to prevent an endless simulation.
    //   4. Compare adc_data with the expected 128-bit conversion code.
    //   5. Check that the done pulse returns low.
    //
    // Arguments:
    //   sample    - Q16-scaled input voltage.
    //   expected  - Expected 128-bit output code.
    //   test_name - Label used in PASS/FAIL messages.
    // ------------------------------------------------------------------------
    task check_conversion;
        input [16:0]  sample;
        input [127:0] expected;
        input [255:0] test_name;

        integer timeout_count;
        reg completed;

        begin
            // Wait for a falling edge before changing test inputs. This avoids
            // a race with the DUT, which samples control/input signals on posedge.
            @(negedge clk);
            voltage_q16 = sample; // Apply the voltage sample for this test.
            start = 1'b1;          // Request a conversion.

            // Keep start high across the next rising edge so the idle controller
            // can accept the request. Deassert it at the following falling edge.
            @(negedge clk);
            start = 1'b0;

            // Initialize the completion flag and timeout counter before waiting.
            // The timeout prevents a broken DUT from hanging the simulation.
            completed = 1'b0;
            timeout_count = 0;

            while (!completed && timeout_count < 6) begin
                @(posedge clk); // Observe a rising clock edge.
                #1;             // Let the DUT's nonblocking assignments settle.

                // Case equality ensures that only a definite logic 1 is accepted.
                if (done === 1'b1)
                    completed = 1'b1;

                // Count this sampled edge toward the timeout limit.
                timeout_count = timeout_count + 1;
            end

            // First check that conversion completed. If it did, compare the
            // actual output with the expected code; !== also detects X/Z bits.
            if (!completed) begin
                report_fail({test_name, " timeout"});
            end else if (adc_data !== expected) begin
                $display("  Input Q16: %0d", sample);
                $display("  Expected : %032h", expected);
                $display("  Actual   : %032h", adc_data);
                report_fail(test_name);
            end else begin
                report_pass(test_name);
            end

            // Check the done pulse only after a completed conversion.
            // done is asserted by a nonblocking assignment at the completion
            // edge, so it remains high until the NEXT rising clock edge.
            // Wait for that edge, then allow nonblocking assignments to settle.
            if (completed) begin
                @(posedge clk);
                #1;

                if (done === 1'b0)
                    report_pass("done pulse clears correctly");
                else
                    report_fail("done pulse did not clear");
            end else begin
                // A timeout is already a failure. Do not perform a pulse-clear
                // check on a conversion that never completed.
                $display("INFO: Skipping done-clear check because conversion timed out.");
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Main simulation sequence
    // Runs the reset test, upward/downward voltage sweep, and extra checks.
    // ------------------------------------------------------------------------
    initial begin
        // Initialize counters and drive all inputs to known starting values.
        pass_count = 0;
        fail_count = 0;
        rst = 1'b1;
        start = 1'b0;
        voltage_q16 = 17'd0;

        // Hold reset through two active clock edges so the synchronous reset
        // logic in the DUT can clear the result and status outputs.
        repeat (2) @(posedge clk);
        #1; // Wait for nonblocking assignments to complete.

        // Verify that reset clears the output and both controller status flags.
        if (adc_data === 128'd0 && busy === 1'b0 && done === 1'b0)
            report_pass("initial synchronous reset");
        else
            report_fail("initial synchronous reset");

        // Deassert reset on a falling edge to avoid changing it at posedge.
        @(negedge clk);
        rst = 1'b0;

        // --------------------------------------------------------------------
        // VOLTAGE SWEEP UP
        // Test the input at 0, 0.25, 0.50, 0.75, and 1.00 V in ascending order.
        // Each call waits for conversion completion and checks the expected code.
        // --------------------------------------------------------------------
        // 0 V is represented by input zero and maps to an all-zero output.
        check_conversion(
            17'd0,
            128'h00000000000000000000000000000000,
            "sweep up: 0.00 V"
        );

        // 0.25 V = 16384 / 65536; expected code is approximately 25% scale.
        check_conversion(
            17'd16384,
            128'h3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            "sweep up: 0.25 V"
        );

        // 0.50 V = 32768 / 65536; expected code is approximately 50% scale.
        check_conversion(
            17'd32768,
            128'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            "sweep up: 0.50 V"
        );

        // 0.75 V = 49152 / 65536; expected code is approximately 75% scale.
        check_conversion(
            17'd49152,
            128'hBFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            "sweep up: 0.75 V"
        );

        // 1.00 V is full scale; the modeled output saturates to all ones.
        check_conversion(
            17'd65536,
            128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            "sweep up: 1.00 V"
        );

        // --------------------------------------------------------------------
        // VOLTAGE SWEEP DOWN
        // Step back from 1.00 V to 0 V using the same 0.25 V intervals.
        // This confirms that the design responds correctly to decreasing input.
        // --------------------------------------------------------------------
        check_conversion(
            17'd49152,
            128'hBFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            "sweep down: 0.75 V"
        );

        check_conversion(
            17'd32768,
            128'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            "sweep down: 0.50 V"
        );

        check_conversion(
            17'd16384,
            128'h3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            "sweep down: 0.25 V"
        );

        check_conversion(
            17'd0,
            128'h00000000000000000000000000000000,
            "sweep down: 0.00 V"
        );

        // --------------------------------------------------------------------
        // EXTRA TEST: Overrange saturation
        // An input above the modeled 1.00 V full scale should produce the
        // maximum unsigned 128-bit output code (all bits set).
        // --------------------------------------------------------------------
        check_conversion(
            17'd65537,
            128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            "overrange saturation"
        );

        // --------------------------------------------------------------------
        // EXTRA TEST: Output retention
        // Save the most recent output, then wait three rising edges without
        // asserting start. The registered output should remain unchanged.
        // --------------------------------------------------------------------
        held_data = adc_data;       // Snapshot the current ADC output.
        repeat (3) @(posedge clk);  // No conversion request during this interval.
        #1;                         // Allow any scheduled updates to settle.

        if (adc_data === held_data && done === 1'b0)
            report_pass("output holds between conversions");
        else
            report_fail("output holds between conversions");

        // --------------------------------------------------------------------
        // EXTRA TEST: A start pulse sampled while busy must be ignored.
        // The first request is accepted at a rising edge. The second request
        // is asserted at the following falling edge, so it is sampled at the
        // next rising edge while the controller is in ST_CONVERT.
        // --------------------------------------------------------------------
        @(negedge clk);
        voltage_q16 = 17'd16384;
        start = 1'b1;

        @(negedge clk);
        // First request has now been accepted; pulse start again while busy.
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        // Wait for the first conversion to finish.
        wait (done === 1'b1);
        #1;

        if (adc_data === 128'h3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            report_pass("start while busy is ignored");
        else
            report_fail("start while busy is ignored");

        // Allow the controller to return to idle and verify no second
        // conversion was started by the busy-time request.
        @(negedge clk);
        #1;
        if (busy === 1'b0 && done === 1'b0)
            report_pass("controller returns to idle after conversion");
        else
            report_fail("controller returns to idle after conversion");

        // --------------------------------------------------------------------
        // EXTRA TEST: Reset after conversion
        // Confirm that asserting synchronous reset clears the result, busy,
        // and done signals after the next rising clock edge.
        // --------------------------------------------------------------------
        @(negedge clk);
        rst = 1'b1;

        @(posedge clk);
        #1;

        if (adc_data === 128'd0 && busy === 1'b0 && done === 1'b0)
            report_pass("reset clears result and control");
        else
            report_fail("reset clears result and control");

        // --------------------------------------------------------------------
        // Final verification summary
        // Report the total PASS/FAIL counts and indicate the overall outcome.
        // --------------------------------------------------------------------
        $display("==============================================");
        $display("128-BIT ADC TESTBENCH SUMMARY");
        $display("Tests passed: %0d", pass_count);
        $display("Tests failed: %0d", fail_count);
        $display("==============================================");

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTBENCH FAILED");

        #10;
        $finish;
    end

endmodule
