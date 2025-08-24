#=============================================================================
# Smart IoT Sensor Interface Controller - Enhanced Makefile
# Author: Prabhat Pandey
# Date: August 24, 2025
# Description: Build scripts for multiple simulation tools including Vivado
#=============================================================================

# Project configuration
PROJECT_NAME = iot_sensor_controller
TOP_MODULE = iot_sensor_controller
TB_MODULE = tb_iot_sensor_controller

# Source directories
RTL_DIR = rtl
TB_DIR = testbench
SIM_DIR = sim
SCRIPTS_DIR = scripts

# RTL source files
RTL_SOURCES = \
    $(RTL_DIR)/common/iot_sensor_pkg.sv \
    $(RTL_DIR)/common/sync_fifo.sv \
    $(RTL_DIR)/common/priority_arbiter.sv \
    $(RTL_DIR)/sensor_interfaces/i2c_master.sv \
    $(RTL_DIR)/sensor_interfaces/spi_master.sv \
    $(RTL_DIR)/sensor_interfaces/temperature_sensor_interface.sv \
    $(RTL_DIR)/sensor_interfaces/humidity_sensor_interface.sv \
    $(RTL_DIR)/sensor_interfaces/motion_sensor_interface.sv \
    $(RTL_DIR)/packet_framer/packet_framer.sv \
    $(RTL_DIR)/packet_framer/serial_transmitter.sv \
    $(RTL_DIR)/power_controller/power_controller.sv \
    $(RTL_DIR)/$(TOP_MODULE).sv

# Testbench files
TB_SOURCES = \
    $(TB_DIR)/integration_tests/$(TB_MODULE).sv

# Unit test files
UNIT_TESTS = \
    $(TB_DIR)/unit_tests/tb_sync_fifo.sv \
    $(TB_DIR)/unit_tests/tb_priority_arbiter.sv

# Simulation parameters
SIM_TIME = 50ms
WAVE_FILE = $(SIM_DIR)/$(PROJECT_NAME).vcd

#=============================================================================
# Vivado Targets (Primary)
#=============================================================================
.PHONY: vivado vivado-create vivado-sim vivado-unit-tests vivado-synthesis vivado-gui vivado-clean

# Main Vivado target - creates project and runs system test
vivado: vivado-create vivado-sim

# Create Vivado project
vivado-create:
	@echo "Creating Vivado project..."
	@vivado -mode batch -source $(SCRIPTS_DIR)/create_project.tcl
	@echo "Vivado project created successfully!"

# Run system simulation in Vivado
vivado-sim: 
	@echo "Running Vivado simulation..."
	@if [ ! -d "vivado_project" ]; then $(MAKE) vivado-create; fi
	@cd vivado_project && vivado -mode batch -source ../$(SCRIPTS_DIR)/run_simulation.tcl -tclargs system_test
	@echo "Vivado simulation completed!"

# Run unit tests in Vivado
vivado-unit-tests:
	@echo "Running Vivado unit tests..."
	@if [ ! -d "vivado_project" ]; then $(MAKE) vivado-create; fi
	@cd vivado_project && vivado -mode batch -source ../$(SCRIPTS_DIR)/run_simulation.tcl -tclargs unit_tests
	@echo "Vivado unit tests completed!"

# Run synthesis in Vivado
vivado-synthesis:
	@echo "Running Vivado synthesis..."
	@if [ ! -d "vivado_project" ]; then $(MAKE) vivado-create; fi
	@cd vivado_project && vivado -mode batch -source ../$(SCRIPTS_DIR)/run_synthesis.tcl
	@echo "Vivado synthesis completed!"

# Open Vivado GUI
vivado-gui:
	@echo "Opening Vivado GUI..."
	@if [ ! -d "vivado_project" ]; then $(MAKE) vivado-create; fi
	@cd vivado_project && vivado $(PROJECT_NAME).xpr &
	@echo "Vivado GUI launched!"

# Clean Vivado project
vivado-clean:
	@echo "Cleaning Vivado project..."
	@rm -rf vivado_project
	@rm -rf .Xil
	@rm -f *.jou *.log
	@rm -f utilization_report.txt timing_report.txt
	@rm -f vivado_*.backup.jou vivado_*.backup.log
	@echo "Vivado project cleaned!"

#=============================================================================
# Cross-Platform Vivado Runner Scripts
#=============================================================================
.PHONY: vivado-runner-test

# Test Vivado runner scripts
vivado-runner-test:
	@echo "Testing Vivado runner scripts..."
	@chmod +x $(SCRIPTS_DIR)/vivado_runner.sh
	@echo "Linux/Mac: Use './$(SCRIPTS_DIR)/vivado_runner.sh <command>'"
	@echo "Windows: Use '$(SCRIPTS_DIR)/vivado_runner.bat <command>'"
	@echo "Available commands: create, unit_tests, system_test, synthesis, gui, clean"

#=============================================================================
# Icarus Verilog + GTKWave (Alternative)
#=============================================================================
.PHONY: iverilog clean unit_tests view

iverilog: $(SIM_DIR)/$(PROJECT_NAME)_iv
	cd $(SIM_DIR) && vvp $(PROJECT_NAME)_iv

$(SIM_DIR)/$(PROJECT_NAME)_iv: $(RTL_SOURCES) $(TB_SOURCES) | $(SIM_DIR)
	iverilog -g2012 -Wall -Winfloop \
		-DSIMULATION \
		-I$(RTL_DIR)/common \
		-I$(RTL_DIR)/sensor_interfaces \
		-I$(RTL_DIR)/packet_framer \
		-I$(RTL_DIR)/power_controller \
		-o $(SIM_DIR)/$(PROJECT_NAME)_iv \
		$(RTL_SOURCES) $(TB_SOURCES)

#=============================================================================
# Verilator (Alternative)
#=============================================================================
.PHONY: verilator

verilator: $(SIM_DIR)/obj_dir/V$(TB_MODULE)
	cd $(SIM_DIR) && ./obj_dir/V$(TB_MODULE)

$(SIM_DIR)/obj_dir/V$(TB_MODULE): $(RTL_SOURCES) $(TB_SOURCES) | $(SIM_DIR)
	cd $(SIM_DIR) && verilator -Wall --cc --exe --build \
		-DSIMULATION \
		-I../$(RTL_DIR)/common \
		-I../$(RTL_DIR)/sensor_interfaces \
		-I../$(RTL_DIR)/packet_framer \
		-I../$(RTL_DIR)/power_controller \
		$(addprefix ../,$(RTL_SOURCES)) $(addprefix ../,$(TB_SOURCES))

#=============================================================================
# ModelSim/Questa (Alternative)
#=============================================================================
.PHONY: modelsim questa

modelsim questa:
	@echo "Creating ModelSim/Questa project..."
	@mkdir -p $(SIM_DIR)/modelsim
	cd $(SIM_DIR)/modelsim && \
	echo "vlib work" > compile.do && \
	echo "vmap work work" >> compile.do && \
	$(foreach src,$(RTL_SOURCES),echo "vlog +define+SIMULATION -sv ../$(src)" >> compile.do;) \
	$(foreach src,$(TB_SOURCES),echo "vlog +define+SIMULATION -sv ../$(src)" >> compile.do;) \
	echo "vsim -t ps -lib work $(TB_MODULE) -do \"add wave -radix hex sim:/$(TB_MODULE)/*; run $(SIM_TIME); quit\"" >> compile.do
	@echo "Run: cd $(SIM_DIR)/modelsim && vsim -do compile.do"

#=============================================================================
# Unit Tests (All Tools)
#=============================================================================
.PHONY: unit_tests test_fifo test_arbiter

# Unit tests - defaults to Vivado if available, otherwise Icarus
unit_tests:
	@if command -v vivado >/dev/null 2>&1; then \
		$(MAKE) vivado-unit-tests; \
	else \
		$(MAKE) icarus-unit-tests; \
	fi

# Icarus Verilog unit tests
icarus-unit-tests: test_fifo test_arbiter

test_fifo: $(SIM_DIR)/tb_sync_fifo_iv
	cd $(SIM_DIR) && vvp tb_sync_fifo_iv

$(SIM_DIR)/tb_sync_fifo_iv: $(RTL_DIR)/common/sync_fifo.sv $(TB_DIR)/unit_tests/tb_sync_fifo.sv | $(SIM_DIR)
	iverilog -g2012 -Wall -DSIMULATION \
		-I$(RTL_DIR)/common \
		-o $(SIM_DIR)/tb_sync_fifo_iv \
		$(RTL_DIR)/common/sync_fifo.sv \
		$(TB_DIR)/unit_tests/tb_sync_fifo.sv

test_arbiter: $(SIM_DIR)/tb_priority_arbiter_iv
	cd $(SIM_DIR) && vvp tb_priority_arbiter_iv

$(SIM_DIR)/tb_priority_arbiter_iv: | $(SIM_DIR)
	iverilog -g2012 -Wall -DSIMULATION \
		-I$(RTL_DIR)/common \
		-o $(SIM_DIR)/tb_priority_arbiter_iv \
		$(RTL_DIR)/common/iot_sensor_pkg.sv \
		$(RTL_DIR)/common/sync_fifo.sv \
		$(RTL_DIR)/common/priority_arbiter.sv \
		$(TB_DIR)/unit_tests/tb_priority_arbiter.sv

#=============================================================================
# Synthesis (Multiple Tools)
#=============================================================================
.PHONY: synthesis yosys-synthesis

# Synthesis - defaults to Vivado if available, otherwise Yosys
synthesis:
	@if command -v vivado >/dev/null 2>&1; then \
		$(MAKE) vivado-synthesis; \
	else \
		$(MAKE) yosys-synthesis; \
	fi

# Yosys synthesis (alternative)
yosys-synthesis: $(SIM_DIR)/$(PROJECT_NAME)_synth.json
	@echo "Yosys synthesis completed. Results in $(SIM_DIR)/$(PROJECT_NAME)_synth.json"

$(SIM_DIR)/$(PROJECT_NAME)_synth.json: $(RTL_SOURCES) scripts/synth.ys | $(SIM_DIR)
	cd $(SIM_DIR) && yosys ../scripts/synth.ys

#=============================================================================
# Utilities
#=============================================================================
.PHONY: view clean help lint gui

# Open waveform viewer (tool-dependent)
view:
	@if [ -f "vivado_project/$(PROJECT_NAME).sim/sim_1/behav/xsim/$(TB_MODULE)_behav.wdb" ]; then \
		echo "Opening Vivado waveform..."; \
		cd vivado_project && vivado -mode gui $(PROJECT_NAME).xpr & \
	elif [ -f "$(WAVE_FILE)" ]; then \
		echo "Opening GTKWave..."; \
		gtkwave $(WAVE_FILE) --vcd & \
	else \
		echo "No waveform file found. Run simulation first."; \
	fi

# Clean all generated files  
clean:
	@echo "Cleaning all generated files..."
	rm -rf $(SIM_DIR)/*
	rm -rf vivado_project
	rm -rf .Xil
	rm -f *.vcd *.vvp *.jou *.log
	rm -f utilization_report.txt timing_report.txt
	rm -f vivado_*.backup.jou vivado_*.backup.log
	@echo "Clean completed!"

# Create simulation directory
$(SIM_DIR):
	mkdir -p $(SIM_DIR)

# Lint check
lint:
	@echo "Running Verilator lint check..."
	verilator --lint-only -Wall \
		-I$(RTL_DIR)/common \
		-I$(RTL_DIR)/sensor_interfaces \
		-I$(RTL_DIR)/packet_framer \
		-I$(RTL_DIR)/power_controller \
		$(RTL_SOURCES)

# Open appropriate GUI
gui:
	@if command -v vivado >/dev/null 2>&1; then \
		$(MAKE) vivado-gui; \
	else \
		echo "Vivado not available. Use 'make view' for GTKWave after simulation."; \
	fi

# Help message
help:
	@echo "IoT Sensor Controller - Multi-Tool Build System"
	@echo ""
	@echo "=== VIVADO TARGETS (Primary) ==="
	@echo "  vivado           - Create project and run system test"
	@echo "  vivado-create    - Create Vivado project only"
	@echo "  vivado-sim       - Run Vivado system simulation"
	@echo "  vivado-unit-tests- Run Vivado unit tests"
	@echo "  vivado-synthesis - Run Vivado synthesis"
	@echo "  vivado-gui       - Open Vivado GUI"
	@echo "  vivado-clean     - Clean Vivado project"
	@echo ""
	@echo "=== CROSS-PLATFORM SCRIPTS ==="
	@echo "  Linux/Mac: ./scripts/vivado_runner.sh <command>"
	@echo "  Windows:   scripts\vivado_runner.bat <command>"
	@echo "  Commands:  create, unit_tests, system_test, synthesis, gui, clean"
	@echo ""
	@echo "=== ALTERNATIVE TOOLS ==="
	@echo "  iverilog         - Simulate with Icarus Verilog"
	@echo "  verilator        - Simulate with Verilator"
	@echo "  modelsim         - Generate ModelSim script"
	@echo ""
	@echo "=== UNIVERSAL TARGETS ==="
	@echo "  unit_tests       - Run unit tests (auto-detect tool)"
	@echo "  synthesis        - Run synthesis (auto-detect tool)"
	@echo "  lint             - Lint check with Verilator"
	@echo "  gui              - Open GUI (auto-detect tool)"
	@echo "  view             - View waveforms (auto-detect tool)"
	@echo "  clean            - Clean all generated files"
	@echo "  help             - Show this help"
	@echo ""
	@echo "=== QUICK START WITH VIVADO ==="
	@echo "  make vivado      - Complete Vivado simulation"
	@echo "  make vivado-gui  - Open in Vivado GUI"
	@echo ""

# Default target - use Vivado if available, otherwise Icarus
all:
	@if command -v vivado >/dev/null 2>&1; then \
		$(MAKE) vivado; \
	else \
		$(MAKE) iverilog && $(MAKE) icarus-unit-tests; \
	fi

# Set default target
.DEFAULT_GOAL := help
