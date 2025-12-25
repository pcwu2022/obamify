# Final Project for DE2-115 FPGA Board

## Project Overview
This project is designed for the DE2-115 FPGA development board. It contains a complete hardware design, including source code, simulation scripts, and build files. The project is organized to facilitate synthesis, simulation, and implementation on the target hardware.

## Directory Structure
- **DE2_115.qpf / DE2_115.qsf**: Quartus project and settings files.
- **db/**: Quartus database files (auto-generated during compilation).
- **incremental_db/**: Incremental compilation database (auto-generated).
- **output_files/**: Compilation outputs (e.g., bitstreams, reports).
- **python_sim/**: Python scripts for simulation or automation.
- **src/**: Main source code directory (SystemVerilog, Verilog, VHDL, etc.).
- **.qsys_edit/**: Qsys system integration files.
- **PLLJ_PLLSPE_INFO.txt, stp1.stp, tape_out.yba**: Miscellaneous project files.

## Source Code Modules
All main design files are located in the `src/` directory. The `db/` directory contains auto-generated or compiled files, not meant for direct editing.

### Key Modules (Typical Examples)
> **Note:** The following are typical module types found in such projects. For exact details, refer to the `src/` directory.

- **Top-level Module**: Instantiates and connects all submodules, interfaces with the FPGA board's I/O.
- **PLL/Clock Modules**: Manage clock generation and distribution (e.g., `altpll_*` files).
- **Memory Modules**: RAM/ROM blocks, often named `altsyncram_*`.
- **FIFO Modules**: Dual-clock FIFOs for clock domain crossing (e.g., `dcfifo_*`).
- **Counter/Gray Code Modules**: Implement counters and gray code logic (e.g., `a_graycounter_*`, `a_gray2bin_*`).
- **Comparator Modules**: Perform value comparisons (e.g., `cmpr_*`).
- **Custom Logic Modules**: Application-specific logic, such as state machines, data processing, or control units.

### Example: State Machines
Many modules implement state machines. Typical states might include:
- **IDLE**: Waiting for input or trigger.
- **INIT**: Initialization phase.
- **RUN**: Main operation.
- **WAIT**: Waiting for a condition or event.
- **DONE**: Completion or output phase.

Check each module's source code in `src/` for specific state names and transitions.

## Module Relationships
- The **top-level module** connects all submodules, handling data flow and control signals.
- **PLLs** provide clock signals to synchronous modules.
- **FIFOs** and **memory blocks** buffer and store data between processing stages.
- **Counters** and **comparators** are used for control, timing, and decision logic.
- **Custom logic modules** implement the main functionality and interface with external hardware.

## How to Use
1. Open the project in Quartus using `DE2_115.qpf`.
2. Compile the project (Quartus will use files in `src/`).
3. Program the FPGA with the generated bitstream from `output_files/`.
4. For simulation, use scripts or testbenches in `python_sim/` or `src/`.

## Notes
- Do not edit files in `db/` or `incremental_db/` directly.
- For detailed module documentation, see comments in each source file in `src/`.
- For state machine details, refer to the always blocks or process statements in each module.

---
*This README provides a high-level overview. For detailed design and implementation, refer to the source code and in-line comments.*

## Detailed Module Reference
Below is a concise reference for each major module in `src/`, its role, and any explicit FSM states discovered in the source.

- **`DE2_115` (top-level board integration)**: Connects board I/O and instantiates higher-level blocks: `Top`, `SRAM_control`, `SDRAM_control`, `Memory_transfer`, camera modules, `Classifier`, `Obamify`, and `VGA`.
	- Role: glue logic that wires the board peripherals (VGA, SDRAM, SRAM, camera) to the design modules and handles reset/clocking.

- **`Top`**: Global control FSM that sequences the high-level processing pipeline: camera capture -> classifier -> obamify (D.S.P.) -> transfer -> finish.
	- States: `IDLE`, `FIX`, `CLA`, `DSP`, `TRA`, `FIN`.
	- Outputs: start/stop pulses for camera, classifier, obamify, memory-transfer and flags used by the rest of the system.

- **`Obamify`**: The image optimization kernel (epoch / iteration loop). Implements the core randomized swap algorithm accessing SRAM and a target image in memory.
	- Major parameters: image size W=128, epochs N=480, iterations M=1024.
	- SRAM access: treats each pixel as two 16-bit words (32-bit pixel: R,G,B,Loss).
	- Submodules used: `Random_number_21_bit`, `Loss_pixel` (two instances for forward/reverse loss).
	- FSM states (explicit):
		- `S_IDLE`, `S_CALC_INIT`, `S_ADDR_SOURCE_1_LO`, `S_READ_SOURCE_1_LO`, `S_READ_SOURCE_1_HI`,
		- `S_READ_SOURCE_2_LO`, `S_READ_SOURCE_2_HI`, `S_READ_TARGET_1_LO`, `S_READ_TARGET_1_HI`,
		- `S_READ_TARGET_2_LO`, `S_READ_TARGET_2_HI`, `S_CALC_LOSS`, `S_WRITE_SOURCE_1_LO`,
		- `S_WRITE_SOURCE_1_HI`, `S_WRITE_SOURCE_2_LO`, `S_WRITE_SOURCE_2_HI`, `S_NEXT_ITER`,
		- `S_EPOCH_DONE`, `S_FINISHED`.

- **`Random_number_21_bit`**: Xorshift32 PRNG producing a 21-bit value (`o_random_number = state[20:0]`).

- **`Loss_pixel`**: Computes per-pixel loss between two RGB triplets; outputs an 8-bit capped loss value. Used by `Obamify` and `Classifier`-style comparisons.

- **`Classifier`**: Computes a sum-of-absolute-differences (SAD) across five candidate target images to select the closest match for each source pixel.
	- States: `S_IDLE`, `S_SRC`, `S_IMG1`, `S_IMG2`, `S_IMG3`, `S_IMG4`, `S_IMG5`, `S_COMP`, `S_DONE`.
	- Behavior: reads one source pixel then accumulates SAD for each of 5 images; iterates across X/Y image coordinates.

- **`Memory_transfer`**: Moves blocks between SDRAM and SRAM (and vice-versa) for DSP stages and VGA display.
	- States: `S_IDLE`, `S_PREP`, `S_SDRAM_to_SRAM`, `S_SRAM_to_SDRAM`, `S_DONE`.
	- Addresses: uses a fixed `SRAM_BASE_ADDR` and iterates (x,y) across 128x128 image tiles.

- **`SRAM_control`**: Multiplexes accesses to the asynchronous SRAM among four users (memory-transfer, classifier, obamify, optional FX).
	- Local user-state aliases in code: `S_FX`, `S_CL`, `S_MT`, `S_OB` (used to decide which port is active and tri-state SRAM bus control).

- **`SDRAM_control`** and related submodules (`SDRAM_control_interface`, `SDRAM_command`, `SDRAM_datapath`) :
	- Role: full-featured SDRAM controller with two independent write ports and two read ports, internal FIFOs (`SDRAM_WR_FIFO` and `SDRAM_RD_FIFO`) and timing/command generation.
	- Notable behavior: auto arbitration between WR1/WR2 and RD1/RD2 based on FIFO fullness/usage; issues SDRAM commands (activate/read/write/refresh/precharge) through `SDRAM_command` and `SDRAM_control_interface`.
	- FIFOs: `SDRAM_WR_FIFO` and `SDRAM_RD_FIFO` are Altera/Quartus dcfifo components (mixed widths; parameters configured in the sources).

- **`sdram_pll`**: Phase-locked loop generating multiple clocks for SDRAM controller, DRAM clock and VGA/camera clocks (instantiated from the board Qsys/pll settings).

- **Camera flow modules**:
	- `Camera_I2C_config`: configures the D5M camera via I2C (instantiated in `DE2_115`).
	- `Camera_I2C_controller`: low-level I2C controller (uses a counter-driven state sequence to drive I2C start/address/data/stop and detect ACKs).
	- `Camera_capture`: captures raw camera words and tracks frame/line counters; outputs frame, X/Y, and pixel data.
	- `Camera_raw2RGB`: converts raw Bayer-format sensor data into RGB and provides per-pixel coordinates; includes a simple line buffer.
	- `Line_Buffer1`: Altera `altshift_taps` wrapper used for line buffering in camera processing.

- **`VGA`**: Standard VGA timing generator and pixel request interface used to display the processed image. Generates `oRequest` when VGA needs a pixel and outputs `oVGA_R/G/B`, HS/VS and `o_done` at end of a frame.

- **Utilities / Board helpers**:
	- `Reset_Delay`: staged reset release signals used at power-on.
	- `Debounce`: button debounce and edge detection.
	- `SevenHexDecoder`: two-digit seven-segment decoder used to display the `Top` state on the HEX displays.

- **Testbenches**: `tb/tb_*.sv` files contain simple test harnesses for `Camera`, `Obamify`, `Top`, and `VGA`.

## How the pieces relate (high-level)
- The `DE2_115` top wires clocks/resets, instantiates the `Top` sequencer, and contains the camera/SPRAM/SDRAM/VGA glue.
- `Top` asserts per-stage start signals; `Classifier` runs on SRAM reads and writes a 3-bit class result to the `Top` controller.
- `Obamify` is the compute-heavy kernel that reads/writes SRAM pixels and consults a target image area (target base address is selected by `Classifier` result).
- `Memory_transfer` moves data between SDRAM and SRAM to support display and DSP (Obamify) stages, controlled by `Top`/`DE2_115` signals.
- `SDRAM_control` sits between stream FIFOs and the external SDRAM chips to provide burst transfers for VGA and memory-transfer operations.

## Notes and next steps
- For exact signal names, timing constraints and bus widths consult the source files in `src/` (e.g., `Obamify.sv`, `Classifier.sv`, `SDRAM_control.sv`).
- If you want, I can generate a module dependency graph (DOT) or expand any module's README subsection with annotated key signals and address maps.
