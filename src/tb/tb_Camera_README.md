# Camera Module Testbench Documentation

## Overview

This testbench (`tb_Camera.sv`) provides comprehensive testing for the camera modules and I2C initialization system. It verifies the functionality of:

- Camera I2C configuration module
- Camera capture module
- Camera raw to RGB conversion module
- I2C controller communication
- Pixel data flow and processing

## Modules Under Test

### 1. Camera_I2C_config

- Configures the camera sensor via I2C protocol
- Handles zoom mode switching
- Manages exposure adjustment
- Sends configuration data from internal LUT

### 2. Camera_capture

- Captures pixel data from camera sensor
- Tracks X/Y coordinates
- Counts frames
- Generates data valid signals

### 3. Camera_raw2RGB

- Converts raw Bayer pattern to RGB
- Implements line buffering
- Performs demosaicing algorithm
- Outputs RGB pixel data

## Test Cases

### TEST 1: I2C Configuration Initialization

**Purpose**: Verify that I2C configuration sequences are properly generated.

**Procedure**:

- Reset the system
- Monitor I2C clock and data lines
- Check for proper START/STOP conditions
- Verify ACK responses from simulated slave

**Expected Results**:

- I2C transactions should be detected on the bus
- Clock frequency should match configured rate (20 KHz)
- Multiple configuration registers should be written

### TEST 2: Zoom Mode Switch Test

**Purpose**: Verify zoom mode can be toggled and reconfigures the sensor.

**Procedure**:

- Enable zoom mode via `zoom_mode_sw` signal
- Wait for reconfiguration
- Disable zoom mode
- Observe I2C reconfiguration

**Expected Results**:

- Sensor configuration should update when zoom changes
- Different start row/column and size registers should be sent

### TEST 3: Exposure Adjustment Test

**Purpose**: Verify exposure can be increased and decreased.

**Procedure**:

- Pulse `exposure_adj` with `exposure_dec_p = 0` (increase)
- Wait for I2C update
- Pulse `exposure_adj` with `exposure_dec_p = 1` (decrease)
- Monitor exposure register writes

**Expected Results**:

- Exposure register should be updated via I2C
- Value should increase/decrease by configured amount (200)

### TEST 4: Camera Capture - Single Frame

**Purpose**: Verify basic frame capture functionality.

**Procedure**:

- Assert trigger signal to start capture
- Generate frame valid (FVAL) signal
- Generate line valid (LVAL) signal
- Provide pixel data for 32x32 frame
- Check frame counter increments

**Expected Results**:

- Frame counter should increment from 0 to 1
- X counter should count 0-31 per line
- Y counter should count 0-31 per frame
- Data valid (DVAL) should be asserted during capture

### TEST 5: Camera Capture - Multiple Frames

**Purpose**: Verify continuous frame capture.

**Procedure**:

- Generate 3 consecutive frames (16x16 each)
- Monitor frame counter
- Check coordinate tracking across frames

**Expected Results**:

- Frame counter should reach at least 4
- X/Y counters should reset between frames
- No missed frames

### TEST 6: Raw to RGB Conversion

**Purpose**: Verify Bayer demosaicing algorithm.

**Procedure**:

- Generate frame with known pattern
- Monitor RGB outputs
- Check RGB data valid signal
- Verify color channel outputs

**Expected Results**:

- RGB data valid should be asserted for valid pixels
- Color values should be properly interpolated
- Output coordinates should match input/2 (due to Bayer pattern)

### TEST 7: Pixel Coordinates Verification

**Purpose**: Verify X/Y coordinate counters increment correctly.

**Procedure**:

- Generate 32x256 frame
- Monitor X counter for proper increment/wrap
- Check Y counter increments at end of each line
- Verify no unexpected jumps

**Expected Results**:

- X counter should increment 0→1→2...→255→0
- Y counter should increment when X wraps
- No coordinate discontinuities

## Running the Testbench

### Using Icarus Verilog (iverilog)

```bash
# Compile
make compile

# Run simulation
make run

# View waveforms
make view

# Or do all in one step
make test
```

### Using ModelSim/QuestaSim

```bash
# Compile
vlog -sv Camera_I2C_config.sv Camera_I2C_controller.sv Camera_capture.sv Camera_raw2RGB.sv tb_Camera.sv

# Simulate
vsim -c tb_Camera -do "run -all"

# With GUI
vsim tb_Camera
```

### Using Vivado Simulator (xsim)

```bash
# Compile
xvlog --sv Camera_I2C_config.sv Camera_I2C_controller.sv Camera_capture.sv Camera_raw2RGB.sv tb_Camera.sv

# Elaborate
xelab tb_Camera -debug typical

# Simulate
xsim tb_Camera -R
```

## Testbench Architecture

### Clock Domains

- **clk_50mhz**: System clock for I2C configuration (50 MHz, 20ns period)
- **pixclk**: Pixel clock for camera capture (25 MHz, 40ns period)

### I2C Slave Simulation

The testbench includes a simple I2C slave model that:

- Monitors I2C clock (SCLK)
- Detects byte boundaries
- Generates ACK signals at appropriate times (bits 9, 18, 27, 36)
- Simulates successful I2C transactions

### Camera Data Generation

The `generate_frame` task creates realistic camera data:

- Configurable rows and columns
- Proper FVAL (frame valid) timing
- Proper LVAL (line valid) timing
- H-blanking between lines
- V-blanking between frames
- Gradient pattern for visual verification

## Monitoring and Debug

### Signal Probes

Key signals to monitor in waveform viewer:

- `i2c_sclk`, `i2c_sdat` - I2C bus activity
- `fval`, `lval` - Camera timing signals
- `cam_data` - Raw camera pixel data
- `x_cnt`, `y_cnt` - Pixel coordinates
- `frame_cnt` - Frame counter
- `dval` - Data valid from capture
- `rgb_red`, `rgb_green`, `rgb_blue` - RGB outputs
- `rgb_dval` - RGB data valid

### Console Output

The testbench provides detailed console logging:

- Test progress messages
- I2C transaction detection
- Frame generation status
- Pixel coordinate tracking
- RGB output values
- Test pass/fail status

## Expected Output

Successful run should show:

```
===========================================
Camera Module Testbench Starting
===========================================
[200] Reset released

===========================================
TEST 1: I2C Configuration Initialization
===========================================
[300] I2C transaction detected
...

===========================================
Test Summary
===========================================
Total tests run: 50+
Total errors: 0
Status: ALL TESTS PASSED
===========================================
```

## Customization

### Adjusting Frame Sizes

Modify the `generate_frame` task calls:

```systemverilog
generate_frame(rows, cols);  // e.g., generate_frame(480, 640)
```

### Changing Clock Frequencies

Modify clock generation blocks:

```systemverilog
forever #10 clk_50mhz = ~clk_50mhz;  // Change #10 for different frequency
```

### Adding Custom Tests

Add new test sections following the pattern:

```systemverilog
$display("TEST X: Custom Test");
// Test procedures
// Checks and assertions
```

## Troubleshooting

### No I2C Activity

- Check reset signal timing
- Verify clock generation
- Check I2C clock divider configuration

### Frame Counter Not Incrementing

- Verify FVAL edge detection
- Check trigger signal timing
- Ensure proper reset

### RGB Output Not Valid

- Verify input Bayer pattern
- Check line buffer functionality
- Ensure proper Y counter (even/odd lines)

## File Dependencies

```
tb_Camera.sv (testbench)
├── Camera_I2C_config.sv
│   └── Camera_I2C_controller.sv
├── Camera_capture.sv
├── Camera_raw2RGB.sv
└── VGA_Param.vh (configuration header)
```

## Notes

1. The testbench uses a simplified I2C slave model. Real hardware behavior may differ.

2. Camera timing is idealized. Actual sensors may have different blanking periods.

3. The Bayer pattern demosaicing is simplified. Production code may use more sophisticated algorithms.

4. Simulation time is limited to 50ms. Increase timeout for longer tests.

5. VCD file can become large for long simulations. Consider selective dumping for specific signals.

## Future Enhancements

- Add error injection for I2C NACK testing
- Implement more realistic camera sensor model
- Add SDRAM interface testing
- Test VGA output timing
- Add assertions for protocol compliance
- Implement coverage collection
