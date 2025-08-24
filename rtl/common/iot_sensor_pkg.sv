//=============================================================================
// IoT Sensor Controller Package
// Contains all common types, constants, and parameters
//=============================================================================

`timescale 1ns/1ps

package iot_sensor_pkg;

    // Power Management Constants
    typedef enum logic [1:0] {
        PWR_NORMAL = 2'b00,  // Full performance mode
        PWR_LOW    = 2'b01,  // Reduced power mode
        PWR_SLEEP  = 2'b10,  // Sleep mode
        PWR_DEEP   = 2'b11   // Deep sleep mode (reserved)
    } power_mode_e;

    // I2C State Machine Constants
    typedef enum logic [3:0] {
        I2C_IDLE     = 4'b0000,
        I2C_START    = 4'b0001,
        I2C_ADDRESS  = 4'b0010,
        I2C_ACK      = 4'b0011,
        I2C_WRITE    = 4'b0100,
        I2C_READ     = 4'b0101,
        I2C_STOP     = 4'b0110,
        I2C_ERROR    = 4'b0111
    } i2c_state_e;

    // SPI State Machine Constants  
    typedef enum logic [2:0] {
        SPI_IDLE     = 3'b000,
        SPI_START    = 3'b001,
        SPI_TRANSFER = 3'b010,
        SPI_FINISH   = 3'b011,
        SPI_ERROR    = 3'b100
    } spi_state_e;

    // Temperature Sensor States
    typedef enum logic [2:0] {
        TEMP_IDLE      = 3'b000,
        TEMP_START     = 3'b001,
        TEMP_READ_MSB  = 3'b010,
        TEMP_READ_LSB  = 3'b011,
        TEMP_DONE      = 3'b100
    } temp_state_e;

    // Humidity Sensor States
    typedef enum logic [2:0] {
        HUM_IDLE       = 3'b000,
        HUM_START      = 3'b001,
        HUM_READ_MSB   = 3'b010,
        HUM_READ_LSB   = 3'b011,
        HUM_DONE       = 3'b100
    } hum_state_e;

    // Motion Sensor States
    typedef enum logic [2:0] {
        MOTION_IDLE    = 3'b000,
        MOTION_START   = 3'b001,
        MOTION_READ    = 3'b010,
        MOTION_DONE    = 3'b011
    } motion_state_e;

    // Sensor Data Types
    typedef struct packed {
        logic [15:0] temperature;
        logic [15:0] humidity;
        logic        motion_detected;
        logic [31:0] timestamp;
        logic        valid;
    } sensor_data_t;

    // Packet Types
    typedef struct packed {
        logic [7:0]  header;
        logic [7:0]  sensor_id;
        logic [15:0] data_length;
        logic [31:0] timestamp;
        logic [7:0]  checksum;
    } packet_header_t;

    // System Constants
    parameter int CLK_FREQ_MHZ = 100;
    parameter int BAUD_RATE = 115200;
    parameter int FIFO_DEPTH = 16;

    // Clock and Frequency Constants
    parameter int SYSTEM_CLK_FREQ = 100_000_000; // 100 MHz
    parameter int I2C_CLK_FREQ = 400_000;        // 400 kHz
    parameter int SPI_CLK_FREQ = 1_000_000;      // 1 MHz

    // I2C Constants
    parameter logic [6:0] TEMP_SENSOR_ADDR = 7'h48;
    parameter logic [6:0] HUM_SENSOR_ADDR = 7'h40;
    parameter logic [6:0] SENSOR_I2C_ADDR = 7'h48;  // Default

    // SPI Constants
    parameter int SPI_CLK_DIV = 4;

    // Sensor IDs
    parameter logic [7:0] TEMP_SENSOR_ID = 8'h01;
    parameter logic [7:0] HUM_SENSOR_ID = 8'h02;
    parameter logic [7:0] MOTION_SENSOR_ID = 8'h03;

    // FIFO and Buffer Sizes
    parameter int TEMP_FIFO_DEPTH = 8;
    parameter int HUM_FIFO_DEPTH = 8;
    parameter int MOTION_FIFO_DEPTH = 8;
    parameter int TX_FIFO_DEPTH = 16;

endpackage : iot_sensor_pkg
