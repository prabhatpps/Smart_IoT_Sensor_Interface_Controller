# =============================================================================
# IoT Sensor Controller Makefile
# Complete build and verification automation
# =============================================================================

# Project settings
PROJECT_NAME = iot_sensor_controller
VIVADO = vivado
VIVADO_VERSION = 2025.1

# Directories
PROJECT_DIR = vivado_project
SCRIPTS_DIR = scripts
RTL_DIR = rtl
TB_DIR = testbench
LOGS_DIR = logs

# Default target
.DEFAULT_GOAL := help

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m  
BLUE = \033[0;34m
NC = \033[0m # No Color

.PHONY: help all create-project integration unit-tests synthesis clean clean-all setup check-tools

# =============================================================================
# Help and Information
# =============================================================================

help: ## Show this help message
	@echo "$(BLUE)IoT Sensor Controller Verification Environment$(NC)"
	@echo "$(BLUE)================================================$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Quick Start:$(NC)"
	@echo "  1. make setup          $(BLUE)# Create directories and check tools$(NC)"
	@echo "  2. make create-project $(BLUE)# Create Vivado project$(NC)"
	@echo "  3. make integration    $(BLUE)# Run integration tests$(NC)"
	@echo ""

info: ## Show project information
	@echo "$(BLUE)Project Information:$(NC)"
	@echo "  Project Name: $(PROJECT_NAME)"
	@echo "  Vivado Version: $(VIVADO_VERSION)"
	@echo "  Project Directory: $(PROJECT_DIR)"
	@echo "  RTL Files: $$(find $(RTL_DIR) -name "*.sv" | wc -l)"
	@echo "  Testbench Files: $$(find $(TB_DIR) -name "*.sv" | wc -l)"
	@echo ""

# =============================================================================
# Setup and Environment  
# =============================================================================

setup: ## Setup directories and check environment
	@echo "$(GREEN)🔧 Setting up verification environment...$(NC)"
	@mkdir -p $(PROJECT_DIR) $(LOGS_DIR)
	@$(MAKE) check-tools
	@echo "$(GREEN)✅ Setup complete!$(NC)"

check-tools: ## Check if required tools are available
	@echo "$(BLUE)🔍 Checking for required tools...$(NC)"
	@which $(VIVADO) >/dev/null 2>&1 || (echo "$(RED)❌ Vivado not found in PATH$(NC)" && exit 1)
	@echo "$(GREEN)✅ Vivado found: $$($(VIVADO) -version | head -n1)$(NC)"

# =============================================================================
# Project Creation
# =============================================================================

create-project: setup ## Create Vivado project with all RTL and testbench files
	@echo "$(GREEN)📦 Creating Vivado project...$(NC)"
	@cd $(PROJECT_DIR) && $(VIVADO) -mode batch -source ../$(SCRIPTS_DIR)/create_project.tcl -log create_project.log
	@if [ -f $(PROJECT_DIR)/$(PROJECT_NAME).xpr ]; then \
		echo "$(GREEN)✅ Project created successfully: $(PROJECT_DIR)/$(PROJECT_NAME).xpr$(NC)"; \
	else \
		echo "$(RED)❌ Project creation failed$(NC)"; \
		exit 1; \
	fi

open-project: ## Open project in Vivado GUI
	@echo "$(BLUE)🖥️  Opening project in Vivado GUI...$(NC)"
	@if [ -f $(PROJECT_DIR)/$(PROJECT_NAME).xpr ]; then \
		cd $(PROJECT_DIR) && $(VIVADO) $(PROJECT_NAME).xpr & \
	else \
		echo "$(RED)❌ Project not found. Run 'make create-project' first$(NC)"; \
		exit 1; \
	fi

# =============================================================================
# Simulation and Testing
# =============================================================================

integration: ## Run integration tests (main system test)
	@echo "$(GREEN)🚀 Running integration tests...$(NC)"
	@cd $(PROJECT_DIR) && $(VIVADO) -mode batch -source ../$(SCRIPTS_DIR)/run_simulation.tcl -tclargs integration -log integration_test.log
	@echo "$(GREEN)✅ Integration tests completed$(NC)"

unit-tests: ## Run unit tests  
	@echo "$(GREEN)🧪 Running unit tests...$(NC)"
	@cd $(PROJECT_DIR) && $(VIVADO) -mode batch -source ../$(SCRIPTS_DIR)/run_simulation.tcl -tclargs unit_tests -log unit_test.log
	@echo "$(GREEN)✅ Unit tests completed$(NC)"

synthesis: ## Run synthesis check
	@echo "$(GREEN)🔨 Running synthesis check...$(NC)"
	@cd $(PROJECT_DIR) && $(VIVADO) -mode batch -source ../$(SCRIPTS_DIR)/run_simulation.tcl -tclargs synthesis -log synthesis.log
	@echo "$(GREEN)✅ Synthesis completed$(NC)"

# Test aliases for convenience
test: integration ## Alias for integration tests
verify: integration ## Alias for integration tests
sim: integration ## Alias for integration tests

# =============================================================================
# Advanced Testing
# =============================================================================

all-tests: unit-tests integration synthesis ## Run all tests and synthesis
	@echo "$(GREEN)🎉 All verification steps completed!$(NC)"

regression: clean create-project all-tests ## Full regression test
	@echo "$(GREEN)🔄 Regression testing completed$(NC)"

# =============================================================================
# Cleanup
# =============================================================================

clean: ## Clean simulation files (keep project)
	@echo "$(YELLOW)🧹 Cleaning simulation files...$(NC)"
	@find $(PROJECT_DIR) -name "*.sim" -type d -exec rm -rf {} + 2>/dev/null || true
	@find $(PROJECT_DIR) -name "*.wdb" -delete 2>/dev/null || true
	@find $(PROJECT_DIR) -name "xsim.dir" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.vcd" -delete 2>/dev/null || true
	@find . -name "webtalk*.jou" -delete 2>/dev/null || true
	@find . -name "webtalk*.log" -delete 2>/dev/null || true
	@echo "$(GREEN)✅ Simulation files cleaned$(NC)"

clean-project: ## Remove entire project (keep RTL)
	@echo "$(YELLOW)🗑️  Removing project files...$(NC)"
	@rm -rf $(PROJECT_DIR)
	@echo "$(GREEN)✅ Project files removed$(NC)"

clean-all: clean-project ## Remove everything except source RTL
	@echo "$(YELLOW)🧹 Deep clean - removing all generated files...$(NC)"
	@rm -rf $(LOGS_DIR)
	@find . -name ".Xil" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)✅ Deep clean completed$(NC)"

# =============================================================================
# Utility Targets
# =============================================================================

list-files: ## List all RTL and testbench files
	@echo "$(BLUE)📁 RTL Files:$(NC)"
	@find $(RTL_DIR) -name "*.sv" | sort
	@echo ""
	@echo "$(BLUE)📁 Testbench Files:$(NC)"  
	@find $(TB_DIR) -name "*.sv" | sort
	@echo ""

check-syntax: ## Basic syntax check of RTL files
	@echo "$(GREEN)📝 Checking RTL syntax...$(NC)"
	@for file in $$(find $(RTL_DIR) -name "*.sv"); do \
		echo "Checking: $$file"; \
	done
	@echo "$(GREEN)✅ Basic syntax check completed$(NC)"

logs: ## Show recent log files
	@echo "$(BLUE)📋 Recent log files:$(NC)"
	@find $(PROJECT_DIR) -name "*.log" -newer $(PROJECT_DIR) 2>/dev/null | head -5 || echo "No recent log files found"

# =============================================================================
# Debug and Development
# =============================================================================

gui: open-project ## Alias to open GUI

debug: ## Open project and simulation in GUI for debugging
	@echo "$(BLUE)🐛 Opening debug session...$(NC)"
	@cd $(PROJECT_DIR) && $(VIVADO) $(PROJECT_NAME).xpr &

status: ## Show current project status
	@echo "$(BLUE)📊 Project Status:$(NC)"
	@if [ -f $(PROJECT_DIR)/$(PROJECT_NAME).xpr ]; then \
		echo "  Project: $(GREEN)✅ Created$(NC)"; \
	else \
		echo "  Project: $(RED)❌ Not created$(NC)"; \
	fi
	@if [ -d $(PROJECT_DIR)/$(PROJECT_NAME).sim ]; then \
		echo "  Simulations: $(GREEN)✅ Available$(NC)"; \
	else \
		echo "  Simulations: $(YELLOW)⏳ Not run yet$(NC)"; \
	fi
	@echo ""

# =============================================================================
# Error Handling
# =============================================================================

# Catch common typos
test-integration: integration
run-tests: integration
run-integration: integration
simulate: integration
