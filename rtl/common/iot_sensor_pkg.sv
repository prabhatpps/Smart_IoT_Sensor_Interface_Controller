//=============================================================================
// Smart IoT Sensor Interface Controller - Common Package
// Author: Prabhat Pandey
// Date: August 24, 2025
// Description: Common parameters, types, and constants
//=============================================================================

package iot_sensor_pkg;

    // System Parameters
    parameter int SYSTEM_CLK_FREQ = 100_000_000; // 100 MHz
    parameter int TIMESTAMP_WIDTH = 16;
    parameter int SENSOR_DATA_WIDTH = 16;
    parameter int PACKET_ID_WIDTH = 8;

    // Sensor Types
    typedef enum logic [1:0] {
        SENSOR_TEMPERATURE = 2'b00,
        SENSOR_HUMIDITY    = 2'b01,
        SENSOR_MOTION      = 2'b10,
        SENSOR_RESERVED    = 2'b11
    } sensor_type_e;

    // Priority Levels (higher number = higher priority)
    typedef enum logic [1:0] {
        PRIORITY_LOW    = 2'b00,  // Humidity
        PRIORITY_MED    = 2'b01,  // Temperature  
        PRIORITY_HIGH   = 2'b10,  // Motion
        PRIORITY_CRIT   = 2'b11   // Reserved
    } priority_level_e;

    // Packet Structure
    typedef struct packed {
        logic [7:0]  start_delimiter;    // 0x7E
        logic [1:0]  sensor_id;
        logic [5:0]  reserved;
        logic [7:0]  packet_length;
        logic [15:0] timestamp;
        logic [15:0] sensor_data;
        logic [7:0]  checksum;
        logic [7:0]  end_delimiter;      // 0x7E
    } sensor_packet_t;

    // FIFO Parameters
    parameter int FIFO_DEPTH = 8;
    parameter int FIFO_ADDR_WIDTH = 3;

    // Communication Parameters
    parameter int I2C_CLK_FREQ = 100_000;     // 100 KHz
    parameter int SPI_CLK_FREQ = 1_000_000;   // 1 MHz
    parameter int UART_BAUD_RATE = 115200;

    // Packet Constants
    parameter logic [7:0] PACKET_START_DELIM = 8'h7E;
    parameter logic [7:0] PACKET_END_DELIM = 8'h7E;
    parameter logic [7:0] PACKET_LENGTH = 8'd8; // Fixed for this design

    // Power Management
    parameter int IDLE_TIMEOUT_CYCLES = 1000;

    // Sensor Interface States
    typedef enum logic [2:0] {
        I2C_IDLE     = 3'b000,
        I2C_START    = 3'b001,
        I2C_ADDRESS  = 3'b010,
        I2C_READ     = 3'b011,
        I2C_ACK      = 3'b100,
        I2C_STOP     = 3'b101
    } i2c_state_e;

    typedef enum logic [2:0] {
        SPI_IDLE     = 3'b000,
        SPI_CS_LOW   = 3'b001,
        SPI_TRANSFER = 3'b010,
        SPI_CS_HIGH  = 3'b011
    } spi_state_e;

endpackage : iot_sensor_pkg
