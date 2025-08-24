# =============================================================================
# Vivado Project Creation Script (FINAL CORRECTED VERSION)
# Author: Prabhat Pandey
# Date: August 24, 2025
# Description: Creates Vivado project for IoT Sensor Interface Controller
# =============================================================================

# Set project variables
set project_name "iot_sensor_controller"
set project_dir "vivado_project"
set top_module "iot_sensor_controller" 
set testbench_top "tb_iot_sensor_controller"

# Create project directory
file mkdir $project_dir

# Create new project
create_project $project_name $project_dir -part xc7a35tcpg236-1 -force

# Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

puts "Adding RTL source files..."

# Check if files exist before adding them
proc add_file_if_exists {file_path} {
    if {[file exists $file_path]} {
        add_files -norecurse $file_path
        puts "Added: $file_path"
        return 1
    } else {
        puts "WARNING: File not found: $file_path"
        return 0
    }
}

# Add RTL source files with existence check
set rtl_files [list \
    "rtl/common/iot_sensor_pkg.sv" \
    "rtl/common/sync_fifo.sv" \
    "rtl/common/priority_arbiter.sv" \
    "rtl/sensor_interfaces/i2c_master.sv" \
    "rtl/sensor_interfaces/spi_master.sv" \
    "rtl/sensor_interfaces/temperature_sensor_interface.sv" \
    "rtl/sensor_interfaces/humidity_sensor_interface.sv" \
    "rtl/sensor_interfaces/motion_sensor_interface.sv" \
    "rtl/packet_framer/packet_framer.sv" \
    "rtl/packet_framer/serial_transmitter.sv" \
    "rtl/power_controller/power_controller.sv" \
    "rtl/iot_sensor_controller.sv" \
]

set files_added 0
foreach file $rtl_files {
    if {[add_file_if_exists $file]} {
        incr files_added
    }
}

puts "Added $files_added RTL files"

# Set file types to SystemVerilog for all .sv files (CORRECTED)
set all_files [get_files]
set sv_files {}
foreach file $all_files {
    if {[file extension $file] == ".sv"} {
        lappend sv_files $file
    }
}

if {[llength $sv_files] > 0} {
    set_property file_type SystemVerilog $sv_files
    puts "Set [llength $sv_files] files to SystemVerilog type"
} else {
    puts "WARNING: No SystemVerilog files found to set type"
}

# Set top module (CORRECTED)
set top_file_found 0
foreach file [get_files] {
    if {[string match "*$top_module.sv" $file]} {
        set_property top $top_module [current_fileset]
        puts "Set top module: $top_module"
        set top_file_found 1
        break
    }
}

if {!$top_file_found} {
    puts "WARNING: Top module file not found: $top_module.sv"
}

# Update compile order
update_compile_order -fileset sources_1

# Create simulation filesets only if testbench files exist
set unit_test_files [list \
    "testbench/unit_tests/tb_sync_fifo.sv" \
    "testbench/unit_tests/tb_priority_arbiter.sv" \
]

set integration_test_files [list \
    "testbench/integration_tests/tb_iot_sensor_controller.sv" \
]

# Create unit test fileset
set unit_tests_exist 1
foreach file $unit_test_files {
    if {![file exists $file]} {
        set unit_tests_exist 0
        puts "WARNING: Unit test file missing: $file"
    }
}

if {$unit_tests_exist} {
    create_fileset -simset unit_tests
    current_fileset -simset unit_tests
    foreach file $unit_test_files {
        add_files -fileset unit_tests -norecurse $file
    }
    puts "Created unit_tests simulation set"
} else {
    puts "WARNING: Skipping unit_tests fileset - missing files"
}

# Create integration test fileset  
set integration_tests_exist 1
foreach file $integration_test_files {
    if {![file exists $file]} {
        set integration_tests_exist 0
        puts "WARNING: Integration test file missing: $file"
    }
}

if {$integration_tests_exist} {
    create_fileset -simset integration_tests
    current_fileset -simset integration_tests
    foreach file $integration_test_files {
        add_files -fileset integration_tests -norecurse $file
    }
    
    # Set testbench top
    set_property top $testbench_top [get_filesets integration_tests]
    set_property top_lib xil_defaultlib [get_filesets integration_tests]
    puts "Created integration_tests simulation set with top: $testbench_top"
} else {
    puts "WARNING: Skipping integration_tests fileset - missing files"
}

# Set simulation properties for all filesets (CORRECTED)
set sim_filesets [get_filesets -filter {FILESET_TYPE == SimulationSrcs}]
foreach simset $sim_filesets {
    set_property -name {xsim.simulate.runtime} -value {50ms} -objects $simset
    set_property -name {xsim.simulate.log_all_signals} -value {true} -objects $simset
    set_property -name {xsim.simulate.wdb} -value {} -objects $simset
    puts "Configured simulation properties for: $simset"
}

# Set SystemVerilog properties for simulation files
foreach simset $sim_filesets {
    set sim_files [get_files -of_objects $simset]
    set sim_sv_files {}
    foreach file $sim_files {
        if {[file extension $file] == ".sv"} {
            lappend sim_sv_files $file
        }
    }
    if {[llength $sim_sv_files] > 0} {
        set_property file_type SystemVerilog $sim_sv_files
        puts "Set SystemVerilog type for [llength $sim_sv_files] simulation files in $simset"
    }
}

# Update compile order for simulation sets
foreach simset $sim_filesets {
    current_fileset -simset $simset
    update_compile_order -fileset $simset
}

# Save project
save_project -force

# Print summary
puts ""
puts "=========================================="
puts "PROJECT CREATION SUMMARY"
puts "=========================================="
puts "Project Name: $project_name"
puts "Project Directory: $project_dir"
puts "Top Module: $top_module"
puts "RTL Files Added: $files_added"

set total_filesets [llength $sim_filesets]
puts "Simulation Sets: $total_filesets"

foreach simset $sim_filesets {
    set simset_files [llength [get_files -of_objects $simset]]
    puts "  $simset: $simset_files files"
}

puts "=========================================="
puts ""

if {$files_added == [llength $rtl_files]} {
    puts "✅ SUCCESS: Project created successfully!"
    puts ""
    puts "Next steps:"
    puts "1. Run simulation: make vivado-sim"
    puts "2. Open GUI: make vivado-gui"  
    puts "3. Run synthesis: make vivado-synthesis"
} else {
    puts "⚠️  WARNING: Some files were missing during project creation"
    puts "Please check that all source files exist in the correct directories"
}

puts ""
puts "Project file: $project_dir/$project_name.xpr"
puts "To open in GUI: vivado $project_dir/$project_name.xpr"
puts ""
