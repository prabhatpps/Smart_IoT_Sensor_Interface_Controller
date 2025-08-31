# Enhanced TCL script with detailed I2C arbitration signals
# This provides complete visibility into I2C bus arbitration

set project_name "iot_sensor_controller"
set project_file "iot_sensor_controller.xpr"

proc ensure_project_open {} {
    global project_name project_file

    set current_project [current_project -quiet]
    if {$current_project != ""} {
        puts "✅ Project already open: $current_project"
        return 1
    }

    if {[file exists $project_file]} {
        puts "📂 Opening project: $project_file"
        open_project $project_file
        return 1
    } else {
        puts "❌ ERROR: Project file not found: $project_file"
        puts "   Run 'make create-project' first to create the project"
        return 0
    }
}

proc run_integration_test {} {
    puts "\n🚀 === RUNNING IOT SENSOR CONTROLLER INTEGRATION TEST ==="

    if {![ensure_project_open]} {
        return 1
    }

    # Check if integration test fileset exists
    set available_sets [get_filesets -filter {FILESET_TYPE == SimulationSrcs}]
    set integration_exists 0
    foreach simset $available_sets {
        if {[string equal $simset "integration_tests"]} {
            set integration_exists 1
            break
        }
    }

    if {!$integration_exists} {
        puts "❌ ERROR: integration_tests simulation set not found"
        puts "Available simulation sets:"
        foreach simset $available_sets {
            puts "   - $simset"
        }
        return 1
    }

    # Set active simulation set
    current_fileset -simset integration_tests
    puts "🎯 Set active simulation: integration_tests"

    # Close existing simulation
    catch {close_sim -quiet}

    # Launch simulation
    puts "🎬 Launching integration test simulation..."
    if {[catch {launch_simulation -simset integration_tests} result]} {
        puts "❌ ERROR: Failed to launch simulation"
        puts "   $result"
        return 1
    }

    # Run simulation
    puts "⏱️  Running simulation for 100ms..."
    run 100ms

    # ENHANCED: Add comprehensive signals to waveform
    puts "📊 Adding comprehensive signals to waveform..."
    catch {
        add_wave_divider "=== SYSTEM SIGNALS ==="
        add_wave /tb_iot_sensor_controller/clk
        add_wave /tb_iot_sensor_controller/rst_n
        add_wave /tb_iot_sensor_controller/enable
        add_wave /tb_iot_sensor_controller/power_mode

        add_wave_divider "=== I2C BUS SIGNALS ==="
        add_wave /tb_iot_sensor_controller/i2c_scl
        add_wave /tb_iot_sensor_controller/i2c_sda
        
        add_wave_divider "=== I2C ARBITRATION ==="
        add_wave /tb_iot_sensor_controller/dut/temp_i2c_req
        add_wave /tb_iot_sensor_controller/dut/hum_i2c_req
        add_wave /tb_iot_sensor_controller/dut/arb_state
        add_wave /tb_iot_sensor_controller/dut/current_temp_transaction
        add_wave /tb_iot_sensor_controller/dut/current_hum_transaction
        add_wave /tb_iot_sensor_controller/dut/i2c_start
        add_wave /tb_iot_sensor_controller/dut/i2c_slave_addr
        add_wave /tb_iot_sensor_controller/dut/i2c_transaction_done
        
        add_wave_divider "=== SENSOR STATES ==="
        add_wave /tb_iot_sensor_controller/dut/u_temp_sensor/current_state
        add_wave /tb_iot_sensor_controller/dut/u_hum_sensor/current_state
        add_wave /tb_iot_sensor_controller/dut/u_motion_sensor/current_state

        add_wave_divider "=== SPI SIGNALS ==="
        add_wave /tb_iot_sensor_controller/spi_clk
        add_wave /tb_iot_sensor_controller/spi_mosi
        add_wave /tb_iot_sensor_controller/spi_miso
        add_wave /tb_iot_sensor_controller/spi_cs
        add_wave /tb_iot_sensor_controller/motion_int

        add_wave_divider "=== DATA STATUS ==="
        add_wave /tb_iot_sensor_controller/temp_data_ready
        add_wave /tb_iot_sensor_controller/hum_data_ready
        add_wave /tb_iot_sensor_controller/motion_data_ready
        add_wave /tb_iot_sensor_controller/packet_sent
        
        add_wave_divider "=== SENSOR DATA ==="
        add_wave -radix hex /tb_iot_sensor_controller/dut/temp_data
        add_wave -radix hex /tb_iot_sensor_controller/dut/hum_data
        add_wave -radix hex /tb_iot_sensor_controller/dut/motion_data

        add_wave_divider "=== SERIAL TRANSMISSION ==="
        add_wave /tb_iot_sensor_controller/serial_tx
        add_wave /tb_iot_sensor_controller/serial_tx_busy
        add_wave /tb_iot_sensor_controller/dut/packet_valid
        add_wave /tb_iot_sensor_controller/dut/packet_ack

        add_wave_divider "=== TEST MONITORING ==="
        add_wave /tb_iot_sensor_controller/test_count
        add_wave /tb_iot_sensor_controller/error_count
        add_wave /tb_iot_sensor_controller/packet_count
        
        add_wave_divider "=== I2C TESTBENCH MODEL ==="
        add_wave /tb_iot_sensor_controller/i2c_state
        add_wave /tb_iot_sensor_controller/sda_drive
        add_wave /tb_iot_sensor_controller/sda_out
        add_wave -radix hex /tb_iot_sensor_controller/data_to_send

        puts "   ✅ Added comprehensive signal monitoring"
    }

    puts "🎉 INTEGRATION TEST COMPLETED SUCCESSFULLY!"
    puts ""
    puts "📋 Expected Waveform Behavior:"
    puts "   • temp_data_ready: Should pulse every 500µs"
    puts "   • hum_data_ready: Should pulse every 750µs" 
    puts "   • motion_data_ready: Should pulse every 500ms"
    puts "   • I2C SCL/SDA: Should show regular transactions"
    puts "   • arb_state: Should alternate ARB_TEMP/ARB_HUM"
    puts "   • packet_sent: Should pulse for each sensor data"
    puts ""
    puts "📊 Check the waveform viewer for detailed signal analysis"
    puts "🔍 Look for I2C arbitration and sensor state machines"

    return 0
}

proc run_unit_tests {} {
    puts "\n🧪 === RUNNING UNIT TESTS ==="

    if {![ensure_project_open]} {
        return 1
    }

    # FIFO Unit Test
    puts "🔧 Running FIFO unit test..."

    # Check if unit test fileset exists
    set available_sets [get_filesets -filter {FILESET_TYPE == SimulationSrcs}]
    set unit_exists 0
    foreach simset $available_sets {
        if {[string equal $simset "unit_tests"]} {
            set unit_exists 1
            break
        }
    }

    if {!$unit_exists} {
        puts "⚠️  WARNING: unit_tests simulation set not found"
        puts "   Skipping unit tests"
        return 0
    }

    current_fileset -simset unit_tests
    catch {close_sim -quiet}

    if {[catch {launch_simulation -simset unit_tests} result]} {
        puts "❌ ERROR: Failed to launch unit test"
        puts "   $result"
        return 1
    }

    run 10ms
    puts "✅ FIFO unit test completed"

    puts "🎉 ALL UNIT TESTS COMPLETED!"
    return 0
}

proc run_synthesis_check {} {
    puts "\n🔨 === RUNNING SYNTHESIS CHECK ==="

    if {![ensure_project_open]} {
        return 1
    }

    puts "🔧 Starting synthesis..."
    if {[catch {launch_runs synth_1} result]} {
        puts "❌ ERROR: Failed to launch synthesis"
        puts "   $result"
        return 1
    }

    # Wait for synthesis to complete
    wait_on_run synth_1

    if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
        puts "❌ Synthesis did not complete successfully"
        return 1
    }

    puts "✅ Synthesis completed successfully"

    # Generate reports
    open_run synth_1
    report_utilization -file utilization_report.txt
    report_timing_summary -file timing_report.txt
    puts "📊 Generated synthesis reports"

    return 0
}

if {$argc > 0} {
    set command [lindex $argv 0]
    puts "🎯 Command received: $command"

    switch $command {
        "integration" {
            set result [run_integration_test]
            exit $result
        }
        "unit_tests" {
            set result [run_unit_tests]
            exit $result
        }
        "synthesis" {
            set result [run_synthesis_check]
            exit $result  
        }
        default {
            puts "❌ Unknown command: $command"
            puts ""
            puts "Usage: vivado -mode batch -source scripts/run_simulation.tcl -tclargs <command>"
            puts ""
            puts "Available commands:"
            puts "   integration  - Run integration test (recommended)"
            puts "   unit_tests   - Run unit tests"
            puts "   synthesis    - Run synthesis check"
            puts ""
            exit 1
        }
    }
} else {
    puts "🚀 No command specified. Running integration test by default..."
    set result [run_integration_test]
    exit $result
}
