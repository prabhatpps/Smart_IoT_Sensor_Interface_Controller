# =============================================================================
# Vivado Simulation Runner Script
# Author: Prabhat Pandey  
# Date: August 24, 2025
# Description: Automated simulation runner for Vivado
# =============================================================================

# Function to run simulation
proc run_simulation {sim_set sim_time} {
    puts "Running simulation: $sim_set"

    # Set active simulation set
    set_property -name {ACTIVE_SIM} -value $sim_set -objects [current_project]

    # Launch simulation
    launch_simulation -simset $sim_set

    # Run for specified time
    run $sim_time

    # Add all signals to waveform
    add_wave_divider "Top Level Signals"
    add_wave [get_objects -r *]

    puts "Simulation $sim_set completed. Check waveform viewer."
    return 0
}

# Function to run unit tests
proc run_unit_tests {} {
    puts "Starting unit test suite..."

    # Run FIFO test
    if {[file exists "testbench/unit_tests/tb_sync_fifo.sv"]} {
        puts "Running FIFO unit test..."
        create_fileset -simset fifo_test
        add_files -fileset fifo_test -norecurse {
            rtl/common/sync_fifo.sv
            testbench/unit_tests/tb_sync_fifo.sv  
        }
        set_property top tb_sync_fifo [get_filesets fifo_test]
        run_simulation fifo_test 1ms
    }

    # Run arbiter test  
    if {[file exists "testbench/unit_tests/tb_priority_arbiter.sv"]} {
        puts "Running Priority Arbiter unit test..."
        create_fileset -simset arbiter_test
        add_files -fileset arbiter_test -norecurse {
            rtl/common/iot_sensor_pkg.sv
            rtl/common/sync_fifo.sv
            rtl/common/priority_arbiter.sv
            testbench/unit_tests/tb_priority_arbiter.sv
        }
        set_property top tb_priority_arbiter [get_filesets arbiter_test]  
        run_simulation arbiter_test 2ms
    }

    puts "Unit tests completed!"
}

# Function to run full system test
proc run_system_test {} {
    puts "Running full system integration test..."
    run_simulation integration_tests 50ms
    puts "System test completed!"
}

# Function to generate reports
proc generate_reports {} {
    puts "Generating project reports..."

    # Generate utilization report after synthesis
    if {[file exists "vivado_project/iot_sensor_controller.runs/synth_1"]} {
        open_run synth_1
        report_utilization -file utilization_report.txt
        report_timing_summary -file timing_report.txt  
        puts "Reports generated: utilization_report.txt, timing_report.txt"
    } else {
        puts "Run synthesis first to generate utilization reports"
    }
}

# Main execution based on arguments
if {$argc > 0} {
    set command [lindex $argv 0]

    switch $command {
        "unit_tests" {
            run_unit_tests
        }
        "system_test" {  
            run_system_test
        }
        "fifo_test" {
            run_simulation fifo_test 1ms
        }
        "arbiter_test" {
            run_simulation arbiter_test 2ms
        }
        "integration_test" {
            run_simulation integration_tests 50ms
        }
        "reports" {
            generate_reports
        }
        default {
            puts "Usage: vivado -mode tcl -source scripts/run_simulation.tcl -tclargs <command>"
            puts "Commands:"
            puts "  unit_tests      - Run all unit tests"
            puts "  system_test     - Run full system test"  
            puts "  fifo_test       - Run FIFO unit test"
            puts "  arbiter_test    - Run arbiter unit test"
            puts "  integration_test- Run integration test"
            puts "  reports         - Generate synthesis reports"
        }
    }
} else {
    puts "No command specified. Running system test by default..."
    run_system_test
}
