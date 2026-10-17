# 128-Bit Theoretical ADC — Verilog HDL / Vivado

## Project scope

This is a synchronized behavioral/theoretical ADC simulation project. It models a digital fixed-point voltage sample and maps it to a 128-bit output code. It is intended for learning, simulation, and RTL integration practice.

**Important:** this is not a physically realizable 128-bit-precision ADC. Verilog RTL does not directly sense an analog voltage. For physical conversion, use an external ADC or analog front end and implement its FPGA interface.

## Input model

`voltage_q16[16:0]` encodes voltage in units of 1/65536 V:

| Input code | Represented voltage |
|---:|---:|
| 0 | 0.00 V |
| 16384 | 0.25 V |
| 32768 | 0.50 V |
| 49152 | 0.75 V |
| 65536 | 1.00 V |
| >65536 | Overrange; saturates to all ones |

The quantizer implements the intended normalized code mapping:
- 0 V -> 0
- values strictly between 0 and 1 V -> `(voltage_q16[15:0] << 112) - 1`
- 1 V and overrange -> `128'hFFFF...FFFF`

This is a simplified mathematical mapping. It does not model analog noise, aperture jitter, nonlinearity, or real-world 128-bit resolution.

## Modules

- `rtl/adc_quantizer.v`: combinational mathematical mapping.
- `rtl/adc_128_controller.v`: synchronous controller, result register, `busy`, and one-cycle `done`.
- `rtl/adc_128_top.v`: top-level integration.
- `rtl/adc_sync_reset.v`: reusable synchronous reset utility/example; not required by the top-level design.
- `tb/tb_adc_128_top.v`: self-checking testbench.

All sequential logic uses the rising edge of `clk` and synchronous, active-high `rst`.

## Handshake

1. Drive `voltage_q16` to the desired input sample.
2. Assert `start` across a rising clock edge while idle.
3. The controller asserts `busy`.
4. On the next rising edge, it captures the combinational quantizer output, deasserts `busy`, and asserts `done`.
5. `done` is a one-clock pulse. `adc_data` holds its value until another conversion or reset.

`start` should be a one-clock pulse and should be synchronized to `clk`. Keep the input sample stable until the conversion completes.

## Vivado setup

1. Create an RTL project named `ADC_128_Project`.
2. Add `rtl/adc_quantizer.v`, `rtl/adc_128_controller.v`, and `rtl/adc_128_top.v` to Design Sources.
3. Optionally add `rtl/adc_sync_reset.v`; it is a utility and is not instantiated by the top module.
4. Add `tb/tb_adc_128_top.v` to Simulation Sources.
5. Set `tb_adc_128_top` as the simulation top.
6. Run **Run Simulation > Run Behavioral Simulation**.
7. Inspect the Tcl console for `ALL TESTS PASSED` and add `clk`, `rst`, `start`, `voltage_q16`, `adc_data`, `busy`, and `done` to the waveform.

No XDC constraints or FPGA part are required for simulation only.

## Verification checklist

- Synchronous reset clears `adc_data`, `busy`, and `done`.
- Test 0 V, 0.25 V, 0.5 V, 0.75 V, and 1 V.
- Overrange input saturates to all ones.
- `done` is one clock cycle.
- `adc_data` holds between conversions.
- Start while busy is ignored.

## Limitations and extensions

The 128-bit output width is not equivalent to 128 bits of physical measurement accuracy. The input model itself has only 17 bits. The current model uses a combinational quantizer and a short synchronous handshake; it is not a 128-step SAR conversion algorithm. For a more detailed algorithmic model, a clock-by-clock SAR behavioral controller can be added. For physical hardware, interface to an external ADC device.

## Note
The held_data is a temporary storage register in the testbench used to remember the ADC's previous output so we can verify that adc_data does not change when no new conversion is requested.
