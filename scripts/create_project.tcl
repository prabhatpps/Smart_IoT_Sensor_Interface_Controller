#=============================================================================
# Vivado Project Creation Script
# Creates complete IoT Sensor Controller project with all filesets
#=============================================================================

# Project settings
set project_name "iot_sensor_controller"
set project_dir "."
set top_module "iot_sensor_controller" 
set testbench_top "tb_iot_sensor_controller"

# Create project
create_project $project_name $project_dir -part xc7a35tcpg236-1 -force

# Set project properties
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

puts "📦 Adding RTL source files..."

# Helper function to add files safely
proc add_file_if_exists {file_path} {
    if {[file exists $file_path]} {
        add_files -norecurse $file_path
        puts "✅ Added: $file_path"
        return 1
    } else {
        puts "⚠️  WARNING: File not found: $file_path"
        return 0
    }
}

# RTL source files (in dependency order)
set rtl_files [list \
    "../rtl/common/iot_sensor_pkg.sv" \
    "../rtl/common/sync_fifo.sv" \
    "../rtl/common/priority_arbiter.sv" \
    "../rtl/sensor_interfaces/i2c_master.sv" \
    "../rtl/sensor_interfaces/spi_master.sv" \
    "../rtl/sensor_interfaces/temperature_sensor_interface.sv" \
    "../rtl/sensor_interfaces/humidity_sensor_interface.sv" \
    "../rtl/sensor_interfaces/motion_sensor_interface.sv" \
    "../rtl/packet_framer/serial_transmitter.sv" \
    "../rtl/packet_framer/packet_framer.sv" \
    "../rtl/power_controller/power_controller.sv" \
    "../rtl/iot_sensor_controller.sv" \
]

# Add RTL files
set files_added 0
foreach file $rtl_files {
    if {[add_file_if_exists $file]} {
        incr files_added
    }
}
puts "📊 Added $files_added RTL files successfully"

# Set SystemVerilog file types
set all_files [get_files -filter {FILE_TYPE == "Verilog" || FILE_TYPE == "SystemVerilog"}]
set sv_files {}
foreach file $all_files {
    if {[file extension $file] == ".sv"} {
        lappend sv_files $file
    }
}

if {[llength $sv_files] > 0} {
    set_property file_type SystemVerilog $sv_files
    puts "🔧 Set [llength $sv_files] files to SystemVerilog type"
}

# Set top module
set_property top $top_module [current_fileset]
puts "🎯 Set top module: $top_module"

# Update compile order
update_compile_order -fileset sources_1
puts "📋 Updated compile order"

# Create simulation filesets
puts "🧪 Creating simulation filesets..."

# Integration tests
if {[file exists "../testbench/integration_tests/tb_iot_sensor_controller.sv"]} {
    create_fileset -simset integration_tests
    current_fileset -simset integration_tests
    add_files -fileset integration_tests -norecurse "../testbench/integration_tests/tb_iot_sensor_controller.sv"

    # Set testbench top
    set_property top $testbench_top [get_filesets integration_tests]
    set_property top_lib xil_defaultlib [get_filesets integration_tests]
    puts "✅ Created integration_tests simulation set"
} else {
    puts "⚠️  Integration testbench not found"
}

# Unit tests  
if {[file exists "../testbench/unit_tests/tb_sync_fifo.sv"]} {
    create_fileset -simset unit_tests
    current_fileset -simset unit_tests
    add_files -fileset unit_tests -norecurse "../testbench/unit_tests/tb_sync_fifo.sv"

    set_property top "tb_sync_fifo" [get_filesets unit_tests]
    set_property top_lib xil_defaultlib [get_filesets unit_tests]
    puts "✅ Created unit_tests simulation set"
} else {
    puts "⚠️  Unit testbench not found"
}

# Configure simulation properties for all simulation sets
set sim_filesets [get_filesets -filter {FILESET_TYPE == SimulationSrcs}]
foreach simset $sim_filesets {
    # Set runtime and logging
    set_property -name {xsim.simulate.runtime} -value {100ms} -objects $simset
    set_property -name {xsim.simulate.log_all_signals} -value {true} -objects $simset

    # Enable incremental compilation for faster turnaround
    set_property -name {xsim.compile.incremental} -value {true} -objects $simset

    # Set SystemVerilog for testbench files
    set sim_files [get_files -of_objects $simset]
    foreach file $sim_files {
        if {[file extension $file] == ".sv"} {
            set_property file_type SystemVerilog $file
        }
    }

    # Update compile order
    current_fileset -simset $simset
    update_compile_order -fileset $simset

    puts "🔧 Configured simulation properties for: $simset"
}

# Save project
puts "💾 Saving project..."

puts ""
puts "🎉 PROJECT CREATION COMPLETED SUCCESSFULLY!"
puts "📊 Project Summary:"
puts "   - Project name: $project_name"
puts "   - Top module: $top_module"  
puts "   - RTL files: $files_added"
puts "   - Simulation sets: [llength $sim_filesets]"
puts ""
puts "✅ Ready to run simulations!"
puts "   Use: launch_simulation -simset integration_tests"
puts "   Or:  launch_simulation -simset unit_tests"
