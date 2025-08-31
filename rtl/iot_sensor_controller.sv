//=============================================================================
// IoT Sensor Controller - Top Level
// Integrates all sensor interfaces, packet framing, and communication
//=============================================================================

`timescale 1ns/1ps

import iot_sensor_pkg::*;

module iot_sensor_controller (
    input  logic        clk,
    input  logic        rst_n,

    // System control
    input  logic [1:0]  power_mode,
    input  logic        enable,

    // I2C interface (Temperature & Humidity)
    inout  wire         i2c_scl,
    inout  wire         i2c_sda,

    // SPI interface (Motion Sensor)
    output logic        spi_clk,
    output logic        spi_mosi,
    input  logic        spi_miso,
    output logic        spi_cs,

    // Motion interrupt
    input  logic        motion_int,

    // Serial output
    output logic        serial_tx,
    output logic        serial_tx_busy,

    // Status outputs
    output logic        temp_data_ready,
    output logic        hum_data_ready,
    output logic        motion_data_ready,
    output logic        packet_sent
);

    // Internal sensor data signals
    logic [15:0] temp_data;
    logic        temp_valid;
    logic        temp_error;

    logic [15:0] hum_data;
    logic        hum_valid;
    logic        hum_error;

    logic [15:0] motion_data;
    logic        motion_valid;
    logic        motion_error;

    // I2C master signals
    logic        i2c_start;
    logic [6:0]  i2c_slave_addr;
    logic        i2c_read_write_n;
    logic [7:0]  i2c_write_data;
    logic [7:0]  i2c_read_data;
    logic        i2c_transaction_done;
    logic        i2c_ack_error;

    // SPI master signals
    logic        spi_start;
    logic [7:0]  spi_tx_data;
    logic [7:0]  spi_rx_data;
    logic        spi_transaction_done;

    // Packet framer signals
    logic        packet_ready;
    logic [7:0]  packet_data;
    logic        packet_valid;
    logic        packet_ack;

    // Serial transmitter signals
    logic        tx_start;
    logic        tx_done;

    // Power management signals
    logic        temp_clk_en;
    logic        hum_clk_en;
    logic        motion_clk_en;
    logic        tx_clk_en;
    logic        sys_clk_en;

    // Activity indicators for power management
    logic        temp_active;
    logic        hum_active;
    logic        motion_active;
    logic        tx_active;

    assign temp_active = temp_valid || temp_data_ready;
    assign hum_active = hum_valid || hum_data_ready;
    assign motion_active = motion_valid || motion_data_ready || motion_int;
    assign tx_active = serial_tx_busy || packet_valid;

    // Status output assignments
    assign temp_data_ready = temp_valid;
    assign hum_data_ready = hum_valid;
    assign motion_data_ready = motion_valid;

    // Temperature Sensor Interface (I2C)
    temperature_sensor_interface u_temp_sensor (
        .clk                (clk & temp_clk_en),
        .rst_n              (rst_n),
        .enable             (enable),
        .power_mode         (power_mode),
        .sensor_data        (temp_data),
        .data_valid         (temp_valid),
        .data_ready         (),
        .sensor_error       (temp_error),
        .start_read         (i2c_start),
        .slave_addr         (i2c_slave_addr),
        .read_write_n       (i2c_read_write_n),
        .write_data         (i2c_write_data),
        .i2c_read_data      (i2c_read_data),
        .transaction_done   (i2c_transaction_done),
        .ack_error          (i2c_ack_error)
    );

    // Humidity Sensor Interface (I2C) - shared I2C bus with temperature
    humidity_sensor_interface u_hum_sensor (
        .clk                (clk & hum_clk_en),
        .rst_n              (rst_n),
        .enable             (enable),
        .power_mode         (power_mode),
        .sensor_data        (hum_data),
        .data_valid         (hum_valid),
        .data_ready         (),
        .sensor_error       (hum_error),
        .start_read         (),  // Shared I2C - controlled by arbiter
        .slave_addr         (),  // Shared I2C
        .read_write_n       (),  // Shared I2C
        .write_data         (),  // Shared I2C
        .i2c_read_data      (i2c_read_data),
        .transaction_done   (i2c_transaction_done),
        .ack_error          (i2c_ack_error)
    );

    // Motion Sensor Interface (SPI)
    motion_sensor_interface u_motion_sensor (
        .clk                (clk & motion_clk_en),
        .rst_n              (rst_n),
        .enable             (enable),
        .power_mode         (power_mode),
        .motion_int         (motion_int),
        .sensor_data        (motion_data),
        .data_valid         (motion_valid),
        .data_ready         (),
        .sensor_error       (motion_error),
        .start_spi          (spi_start),
        .spi_tx_data        (spi_tx_data),
        .spi_rx_data        (spi_rx_data),
        .spi_done           (spi_transaction_done)
    );

    // I2C Master
    i2c_master u_i2c_master (
        .clk                (clk),
        .rst_n              (rst_n),
        .start_transaction  (i2c_start),
        .slave_addr         (i2c_slave_addr),
        .read_write_n       (i2c_read_write_n),
        .write_data         (i2c_write_data),
        .read_data          (i2c_read_data),
        .transaction_done   (i2c_transaction_done),
        .ack_error          (i2c_ack_error),
        .scl                (i2c_scl),
        .sda                (i2c_sda)
    );

    // SPI Master
    spi_master u_spi_master (
        .clk                (clk),
        .rst_n              (rst_n),
        .start_transaction  (spi_start),
        .tx_data            (spi_tx_data),
        .rx_data            (spi_rx_data),
        .transaction_done   (spi_transaction_done),
        .spi_clk            (spi_clk),
        .spi_mosi           (spi_mosi),
        .spi_miso           (spi_miso),
        .spi_cs             (spi_cs)
    );

    // Packet Framer
    packet_framer u_packet_framer (
        .clk                (clk & tx_clk_en),
        .rst_n              (rst_n),
        .temp_data          (temp_data),
        .temp_valid         (temp_valid),
        .hum_data           (hum_data),
        .hum_valid          (hum_valid),
        .motion_data        (motion_data),
        .motion_valid       (motion_valid),
        .packet_ready       (packet_ready),
        .packet_data        (packet_data),
        .packet_valid       (packet_valid),
        .packet_ack         (packet_ack),
        .packet_sent        (packet_sent)
    );

    // Serial Transmitter
    serial_transmitter u_serial_tx (
        .clk                (clk),
        .rst_n              (rst_n),
        .tx_start           (packet_valid && !serial_tx_busy),
        .tx_data            (packet_data),
        .tx_busy            (serial_tx_busy),
        .tx_done            (tx_done),
        .serial_tx          (serial_tx)
    );

    // Serial transmission control
    assign packet_ack = tx_done || (!packet_valid);

    // Power Controller
    power_controller u_power_ctrl (
        .clk                (clk),
        .rst_n              (rst_n),
        .power_mode         (power_mode),
        .temp_active        (temp_active),
        .hum_active         (hum_active),
        .motion_active      (motion_active),
        .tx_active          (tx_active),
        .temp_clk_en        (temp_clk_en),
        .hum_clk_en         (hum_clk_en),
        .motion_clk_en      (motion_clk_en),
        .tx_clk_en          (tx_clk_en),
        .sys_clk_en         (sys_clk_en)
    );

endmodule : iot_sensor_controller
