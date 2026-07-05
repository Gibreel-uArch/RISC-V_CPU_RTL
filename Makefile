# ==============================================================================
#  Project Configuration & Paths
# ==============================================================================

# Compiler tools
VERILATOR = verilator
CXX       = g++

# Directory paths
SRC_DIR   = src/rtl
INC_DIR   = src/includes
TB_DIR    = testbench
SIM_DIR   = sim
OBJ_DIR   = $(SIM_DIR)/obj_dir
LOG_DIR   = $(SIM_DIR)/logs
WAVE_DIR  = $(SIM_DIR)/waveforms

# Dynamic target modules (Can be overridden from command line)
# Example: make run TOP=counter TB=tb_counter
TOP ?= top
TB  ?= tb

# Project source files
RTL_SRCS  = $(wildcard $(SRC_DIR)/*.sv)
TB_SRC    = $(TB_DIR)/$(TB).cpp

# Executable binary path
SIM_EXE   = $(OBJ_DIR)/V$(TOP)

# ==============================================================================
#  Compiler Flags
# ==============================================================================

# Verilator flags
VERILATOR_FLAGS += -Wall --cc --exe
VERILATOR_FLAGS += --top-module $(TOP)
VERILATOR_FLAGS += -I$(INC_DIR) -I$(SRC_DIR)
VERILATOR_FLAGS += --Mdir $(OBJ_DIR)
VERILATOR_FLAGS += --trace

# Warning suppressions (Optional, modify as needed)
VERILATOR_FLAGS += -Wno-fatal -Wno-UNOPTFLAT

# C++ Compiler flags
CXX_FLAGS += -I$(OBJ_DIR)

# ==============================================================================
#  Build Targets
# ==============================================================================

.PHONY: all compile build run wave clean help

# Default target
all: build

# Create necessary directories
init:
	@mkdir -p $(OBJ_DIR) $(LOG_DIR) $(WAVE_DIR)

# Run Verilator compilation
compile: init $(RTL_SRCS) $(TB_SRC)
	@echo "Running Verilator Compilation..."
	$(VERILATOR) $(VERILATOR_FLAGS) $(RTL_SRCS) $(TB_SRC)

# Compile C++ models into simulation binary executable
build: compile
	@echo "Building Simulation Binary..."
	$(MAKE) -C $(OBJ_DIR) -f V$(TOP).mk V$(TOP)

# Execute the simulation, redirect logs, and move VCD waveform files
run: build
	@echo "Running Simulation..."
	$(SIM_EXE) +VERILATOR_LOGS=$(LOG_DIR) > $(LOG_DIR)/sim.log 2>&1 || (cat $(LOG_DIR)/sim.log && exit 1)
	./$(SIM_EXE)
	@echo "Simulation finished successfully."
	@if [ -f dumpfile.vcd ]; then \
		mv dumpfile.vcd $(WAVE_DIR)/$(TOP).vcd; \
		echo "Waveform file saved to $(WAVE_DIR)/$(TOP).vcd"; \
	elif [ -f *.vcd ]; then \
		mv *.vcd $(WAVE_DIR)/; \
	fi

# Open GTKWave to view the generated VCD file
wave:
	@echo "Opening Waveform in GTKWave..."
	@if [ -f $(WAVE_DIR)/$(TOP).vcd ]; then \
		gtkwave $(WAVE_DIR)/$(TOP).vcd > /dev/null 2>&1 & \
	else \
		echo "Error: Waveform file $(WAVE_DIR)/$(TOP).vcd not found. Run 'make run' first."; \
	fi

# Clean up build artifacts and temporary files
clean:
	@echo "Cleaning simulation workspace..."
	rm -rf $(OBJ_DIR) $(LOG_DIR) $(WAVE_DIR)
	rm -f *.vcd *.vcd.idx

# Print help information
help:
	@echo "Usage: make [target] [TOP=module_name] [TB=tb_name]"
	@echo ""
	@echo "Targets:"
	@echo "  all      : Compile and build the project (default)"
	@echo "  compile  : Run Verilator frontend compilation"
	@echo "  build    : Generate the final executable binary"
	@echo "  run      : Execute simulation and generate VCD waveform file"
	@echo "  wave     : View the generated VCD waveform via GTKWave"
	@echo "  clean    : Remove all generated files, logs, and waveforms"
