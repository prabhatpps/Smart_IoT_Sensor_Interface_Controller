# =============================================================================  
# Vivado Synthesis Script
# Author: Prabhat Pandey
# Date: August 24, 2025
# Description: Automated synthesis for IoT Sensor Controller
# =============================================================================

# Open project
open_project iot_sensor_controller.xpr

# Run synthesis
puts "Starting synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check synthesis results
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

puts "Synthesis completed successfully!"

# Open synthesized design
open_run synth_1 -name synth_1

# Generate reports
puts "Generating synthesis reports..."

report_utilization -file utilization_post_synth.rpt -pb utilization_post_synth.pb
report_timing_summary -max_paths 10 -file timing_summary_post_synth.rpt -pb timing_summary_post_synth.pb
report_power -file power_post_synth.rpt -pb power_post_synth.pb

# Print summary
puts "=== SYNTHESIS SUMMARY ==="
puts "Utilization Report: utilization_post_synth.rpt"
puts "Timing Report: timing_summary_post_synth.rpt" 
puts "Power Report: power_post_synth.rpt"

# Extract key metrics
set util_data [report_utilization -return_string]
puts "\n=== KEY METRICS ==="
if {[regexp {Slice LUTs.*?(\d+)} $util_data -> luts]} {
    puts "LUTs Used: $luts"
}
if {[regexp {Slice Registers.*?(\d+)} $util_data -> regs]} {
    puts "Registers Used: $regs"  
}

puts "Synthesis flow completed!"
