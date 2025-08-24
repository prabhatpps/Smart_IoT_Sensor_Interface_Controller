# Technical Specification: Smart IoT Sensor Interface Controller

## Document Information
- **Author:** Prabhat Pandey
- **Date:** August 24, 2025  
- **Version:** 1.0
- **Project:** IoT Sensor Interface Controller RTL Design

## 1. System Requirements

### 1.1 Functional Requirements
- **FR-001:** Interface with temperature sensor via I2C protocol
- **FR-002:** Interface with humidity sensor via I2C protocol  
- **FR-003:** Interface with motion sensor via SPI protocol
- **FR-004:** Prioritize sensor data (Motion > Temperature > Humidity)
- **FR-005:** Frame sensor data into structured packets
- **FR-006:** Transmit packets via UART serial interface
- **FR-007:** Implement power management with clock gating
- **FR-008:** Support multiple power modes for energy efficiency
- **FR-009:** Generate timestamps for all sensor readings
- **FR-010:** Implement error detection and recovery mechanisms

### 1.2 Non-Functional Requirements
- **NFR-001:** System clock frequency: 100 MHz
- **NFR-002:** I2C clock frequency: 100 kHz
- **NFR-003:** SPI clock frequency: 1 MHz  
- **NFR-004:** UART baud rate: 115200 bps (configurable)
- **NFR-005:** Maximum packet latency: 100 μs
- **NFR-006:** Power consumption: <50% of full-power mode in sleep
- **NFR-007:** FIFO depth: 8 entries per sensor
- **NFR-008:** Synthesis frequency target: >100 MHz

## 2. Interface Specifications

### 2.1 Temperature Sensor Interface (I2C)
- **Protocol:** I2C Master, Standard Mode (100 kHz)
- **Slave Address:** 7'h48 (TMP102 compatible)
- **Data Format:** 12-bit two's complement, 0.0625°C resolution
- **Update Rate:** 2 Hz (500ms interval)
- **Power:** Clock gated when idle >1000 cycles

### 2.2 Humidity Sensor Interface (I2C)  
- **Protocol:** I2C Master, Standard Mode (100 kHz)
- **Slave Address:** 7'h40 (SHT30 compatible)
- **Data Format:** 16-bit unsigned, 0.0015% RH resolution
- **Update Rate:** 0.5 Hz (2ms interval)
- **Power:** Clock gated when idle >1000 cycles

### 2.3 Motion Sensor Interface (SPI)
- **Protocol:** SPI Master, Mode 0 (CPOL=0, CPHA=0)
- **Clock Frequency:** 1 MHz
- **Data Format:** 16-bit signed acceleration data
- **Update Rate:** 1 kHz (1ms interval) or interrupt-driven
- **Interrupt:** External motion interrupt for wake-up
- **Power:** Always active in sleep mode for wake-up

### 2.4 Serial Output Interface (UART)
- **Protocol:** UART, 8N1 format
- **Baud Rate:** 115200 bps (configurable)
- **Flow Control:** None
- **Buffer:** 16-byte FIFO for packet buffering
- **Error Handling:** Frame error detection

## 3. Data Structures

### 3.1 Sensor Data Packet Format
```
Byte 0: Start Delimiter (0x7E)
Byte 1: Sensor ID (bits 1:0) + Reserved (bits 7:2)  
Byte 2: Packet Length (0x08)
Byte 3: Timestamp[15:8]
Byte 4: Timestamp[7:0]
Byte 5: Sensor Data[15:8]
Byte 6: Sensor Data[7:0]
Byte 7: Checksum (Two's complement of sum of bytes 0-6)
Byte 8: End Delimiter (0x7E)
```

### 3.2 Priority Levels
```systemverilog
typedef enum logic [1:0] {
    PRIORITY_LOW  = 2'b00,  // Humidity
    PRIORITY_MED  = 2'b01,  // Temperature
    PRIORITY_HIGH = 2'b10,  // Motion
    PRIORITY_CRIT = 2'b11   // Reserved
} priority_level_e;
```

### 3.3 Power Modes
```systemverilog
typedef enum logic [1:0] {
    PWR_NORMAL = 2'b00,  // All modules active
    PWR_LOW    = 2'b01,  // Reduced polling rates
    PWR_SLEEP  = 2'b10,  // Motion sensor only
    PWR_DEEP   = 2'b11   // All off except wakeup
} power_mode_e;
```

## 4. Module Specifications

### 4.1 I2C Master Module
- **File:** `rtl/sensor_interfaces/i2c_master.sv`
- **Clock Domain:** System clock (100 MHz)
- **States:** IDLE, START, ADDRESS, ACK, READ, STOP
- **Features:**
  - Configurable slave addressing
  - Automatic ACK/NACK generation
  - Error detection (no ACK from slave)
  - Clock stretching tolerance
- **Resource Usage:** ~200 LUTs, 50 registers

### 4.2 SPI Master Module  
- **File:** `rtl/sensor_interfaces/spi_master.sv`
- **Clock Domain:** System clock (100 MHz)
- **States:** IDLE, CS_LOW, TRANSFER, CS_HIGH
- **Features:**
  - Configurable data width (8-32 bits)
  - Configurable clock polarity and phase
  - Full-duplex operation
  - Automatic chip select control
- **Resource Usage:** ~150 LUTs, 40 registers

### 4.3 Priority Arbiter Module
- **File:** `rtl/common/priority_arbiter.sv`
- **Algorithm:** Fixed priority with FIFO buffering
- **Features:**
  - Round-robin within same priority level
  - Overflow detection and reporting
  - Back-pressure flow control
  - Individual FIFO per sensor (8 deep)
- **Resource Usage:** ~300 LUTs, 200 registers, 3 block RAMs

### 4.4 Packet Framer Module
- **File:** `rtl/packet_framer/packet_framer.sv`
- **States:** IDLE, START_DELIM, SENSOR_ID, LENGTH, TIMESTAMP_H, TIMESTAMP_L, DATA_H, DATA_L, CHECKSUM, END_DELIM
- **Features:**
  - Automatic checksum calculation
  - Fixed packet format
  - Error detection for malformed packets
  - Configurable timestamp source
- **Resource Usage:** ~250 LUTs, 80 registers

### 4.5 Power Controller Module
- **File:** `rtl/power_controller/power_controller.sv`
- **Features:**
  - Activity-based clock gating
  - Configurable idle timeouts
  - Multiple power mode support
  - Wake-up event handling
  - Power consumption monitoring
- **Resource Usage:** ~180 LUTs, 120 registers

## 5. Timing Specifications

### 5.1 Clock Domains
- **System Clock:** 100 MHz (10 ns period)
- **I2C Clock:** 100 kHz (10 μs period)
- **SPI Clock:** 1 MHz (1 μs period)
- **UART Bit Clock:** 115.2 kHz (8.68 μs period)

### 5.2 Latency Requirements
- **Sensor to FIFO:** <50 ns (5 system clocks)
- **FIFO to Packet:** <100 ns (10 system clocks)  
- **Packet to Serial:** <1 μs (100 system clocks)
- **End-to-End:** <100 μs (sensor reading to transmission)

### 5.3 Throughput Analysis
- **Maximum Packet Rate:** ~1000 packets/second
- **Serial Bandwidth:** 115.2 kbps
- **Packet Size:** 9 bytes × 10 bits = 90 bits per packet
- **Theoretical Maximum:** 1280 packets/second
- **Practical Limit:** ~800 packets/second (allowing for gaps)

## 6. Power Analysis

### 6.1 Power Modes and Consumption
| Mode | Active Modules | Estimated Power | Notes |
|------|----------------|-----------------|-------|
| Normal | All | 100% | Full operation |
| Low | All (reduced rate) | 70% | Reduced polling |
| Sleep | Motion + Critical | 40% | Motion wake-up |
| Deep | Wake-up only | 20% | External wake-up |

### 6.2 Clock Gating Effectiveness
- **Idle Detection:** 1000-cycle timeout
- **Clock Gating Ratio:** Up to 60% duty cycle reduction
- **Power Savings:** Proportional to gated clock percentage
- **Wake-up Latency:** <10 system clocks

## 7. Error Handling

### 7.1 I2C Communication Errors
- **No ACK from Slave:** Retry after timeout, report error
- **Clock Stretching:** Support indefinite stretching with timeout
- **Bus Collision:** Detect and back-off (future enhancement)

### 7.2 SPI Communication Errors  
- **Timeout Detection:** No response within expected time
- **Data Corruption:** Checksum verification (sensor-dependent)
- **CS Glitching:** Proper setup/hold time enforcement

### 7.3 FIFO Overflow/Underflow
- **Overflow:** Drop oldest data, set error flag
- **Underflow:** Hold previous valid data, continue operation
- **Recovery:** Automatic clearing on successful operation

### 7.4 Packet Integrity
- **Checksum Verification:** Two's complement checksum
- **Frame Error Detection:** Invalid delimiters or length
- **Recovery:** Drop corrupted packet, continue with next

## 8. Verification Plan

### 8.1 Unit Test Coverage
- **FIFO Module:** 100% state coverage, boundary conditions
- **I2C Master:** All I2C protocol states, error conditions
- **SPI Master:** All SPI modes, data widths, timing
- **Priority Arbiter:** All priority combinations, overflow
- **Packet Framer:** All packet fields, checksum verification
- **Power Controller:** All power modes, transitions

### 8.2 Integration Test Scenarios
1. **Concurrent Sensor Operation:** All sensors active simultaneously
2. **Priority Verification:** Higher priority interrupts lower
3. **Power Mode Transitions:** All mode changes with verification
4. **Error Recovery:** Inject errors, verify recovery
5. **Long-Term Operation:** 24-hour continuous operation simulation
6. **Boundary Conditions:** Maximum data rates, full FIFOs

### 8.3 Performance Verification
- **Latency Measurement:** End-to-end timing analysis
- **Throughput Testing:** Maximum sustainable packet rate
- **Power Consumption:** Measure actual vs. predicted power
- **Resource Utilization:** Post-synthesis resource reports

## 9. Implementation Guidelines

### 9.1 Coding Standards
- **Language:** SystemVerilog-2012
- **Style:** Consistent naming, proper indentation
- **Comments:** Comprehensive module and signal documentation
- **Assertions:** SVA for protocol compliance and safety
- **Synthesis:** Synthesizable subset only

### 9.2 Directory Structure
```
rtl/
├── common/           # Shared modules and packages
├── sensor_interfaces/# Sensor-specific interfaces  
├── packet_framer/    # Packet processing modules
├── power_controller/ # Power management
└── *.sv             # Top-level integration

testbench/
├── unit_tests/      # Individual module tests
└── integration_tests/# System-level verification
```

### 9.3 Build System
- **Makefile:** Support for multiple simulators
- **Scripts:** Automated synthesis and analysis
- **Documentation:** Auto-generated from source comments

## 10. Future Enhancements

### 10.1 Protocol Extensions
- **Ethernet Interface:** TCP/IP packet transmission
- **WiFi Integration:** Direct wireless communication  
- **CAN Bus:** Automotive sensor networks
- **USB Interface:** Host computer communication

### 10.2 Advanced Features
- **Sensor Fusion:** Combine multiple sensor data
- **Machine Learning:** Edge inference on sensor data
- **Security:** Encryption and authentication
- **OTA Updates:** Field-programmable sensor parameters

### 10.3 Performance Optimizations
- **Pipeline Architecture:** Parallel sensor processing
- **DMA Integration:** Direct memory access for large data
- **Compression:** Data compression before transmission
- **Adaptive Algorithms:** Dynamic priority adjustment

This technical specification provides the detailed design foundation for implementing the Smart IoT Sensor Interface Controller, ensuring consistent and professional RTL development practices.
