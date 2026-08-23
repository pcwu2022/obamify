# Hyper Obamify

A project from the NTU Digital Circuit Lab.
Created by [Po-Chun Wu](https://github.com/pcwu2022), [Po-An Yu](https://github.com/yba857142), [Zi-Li Lien](https://github.com/LienZiLi)

## Overview

Hyper Obamify is an FPGA implementation of an image transformation algorithm. Given a captured source image and five candidate target images, it first finds the most similar target using a loss function. It then applies the Obamify algorithm: randomized pixel swaps are accepted when they reduce the difference between the source and the selected target.

The design uses hardware concurrency and dedicated memory interfaces to perform the image-processing pipeline much more efficiently than a software-only implementation. It is intended for the Terasic DE2-115 FPGA board.

## Processing Pipeline

The board-level design runs the following stages:

1. Configure the D5M camera over I2C and capture a frame.
2. Convert the camera's Bayer data to RGB using a line buffer.
3. Store the 128x128 RGB source frame in SRAM.
4. Compare the source frame with five candidate images using RGB sum-of-absolute-differences (SAD).
5. Select the single candidate with the smallest full-frame loss.
6. Run Obamify on the source frame. Each iteration selects a random pixel and a random valid neighbor, evaluates the loss before and after swapping them, and keeps the swap only when it improves the result.
7. Transfer an epoch result for VGA display, then continue with the next epoch.
8. Stop after the final epoch and wait for a new capture.

The `Top` controller sequences these stages with the states `IDLE`, `FIX`, `CLA`, `DSP`, `TRA`, and `FIN`.

## Hardware Architecture

The top-level entity is `DE2_115` in `src/DE2-115/DE2_115.sv`. It connects:

- D5M camera capture, I2C configuration, and Bayer-to-RGB conversion
- asynchronous SRAM through `SRAM_control`
- external SDRAM through `SDRAM_control`, read/write FIFOs, and a PLL
- the `Classifier` and `Obamify` processing kernels
- `Memory_transfer` for SDRAM/SRAM image movement
- VGA timing and display output
- reset, button debounce, and seven-segment status output

### Image and Memory Parameters

The current RTL uses:

- image size: 128x128 pixels
- pixel format: 32 bits, `{R, G, B, loss}`
- storage: two 16-bit SRAM words per pixel
- source image base address: `0x28000`
- candidate image base addresses: `0x00000`, `0x08000`, `0x10000`, `0x18000`, and `0x20000`
- Obamify: 1,024 epochs with 256 swap attempts per epoch

The camera path captures a 256-pixel-wide sensor stream and reduces it through the RGB conversion path for the 128x128 processing image.

## Repository Layout

- `DE2_115.qpf`, `DE2_115.qsf`: Quartus project and board/device assignments
- `src/`: SystemVerilog RTL, PLL/FIFO IP files, simulation file lists, scripts, and testbenches
- `src/DE2-115/`: DE2-115 board wrapper and board helper modules
- `src/tb/`: testbenches for the camera path, Obamify, top-level controller, and VGA
- `python_sim/`: Python utilities for generating, resizing, inspecting, and classifying image/target data
- `src/targets.bin`: target-image data used by the hardware flow
- `output_files/`, `db/`, `incremental_db/`: Quartus-generated artifacts when present; do not edit them directly

## Building for the DE2-115

1. Open `DE2_115.qpf` in Quartus Prime 15.0 or a compatible Quartus version.
2. Compile the project. The configured device is Cyclone IV E `EP4CE115F29C7`, and the top-level entity is `DE2_115`.
3. Program the board with the generated programming file from `output_files/`.

The board flow requires the DE2-115 hardware, D5M camera, VGA display, and the appropriate target-image data. Pin assignments and timing constraints are maintained in the Quartus settings and the board-specific source directory.

## Simulation

The checked-in scripts use Synopsys VCS and are run from `src/`:

```bash
./01_run_top
./01_run_vga
```

The scripts compile and run the file lists `top.f` and `vga.f`, respectively, and write simulation output to `sim.log`. Generated VCS and waveform files can be removed with:

```bash
./99_clean
```

The testbenches are focused module-level experiments rather than a complete simulation of the physical camera, SDRAM, SRAM, and VGA board environment. The camera testbench also depends on its documented simulator setup and stimulus assumptions.

## Main Modules

- `DE2_115`: board integration and peripheral wiring
- `Top`: high-level pipeline controller
- `Classifier`: full-frame SAD comparison against five targets
- `Obamify`: randomized swap optimizer and epoch controller
- `Memory_transfer`: 128x128 image transfers between SDRAM and SRAM
- `SRAM_control`: arbitrates SRAM access among processing and transfer modules
- `SDRAM_control`: external SDRAM command, datapath, and FIFO control
- `Camera_capture`, `Camera_raw2RGB`: camera capture and RGB conversion
- `VGA`: display timing and processed-image output
- `Random_number_21_bit`, `Loss_pixel`: Obamify random-number and loss primitives

For implementation details, refer to the module interfaces and state machines in `src/`.
