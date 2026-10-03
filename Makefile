# ==============================================================================
#  Project Configuration & Paths
# ==============================================================================

VERILATOR = verilator
CXX       = g++

SRC_DIR   = src/rtl
INC_DIR   = src/includes
TB_DIR    = testbench
SIM_DIR   = sim
OBJ_DIR   = $(SIM_DIR)/obj_dir
LOG_DIR   = $(SIM_DIR)/logs
WAVE_DIR  = $(SIM_DIR)/waveforms

# Dynamic target modules (overridable from command line)
TOP  ?= top
TB   ?= $(TOP)_tb
TEST ?= program.hex

# Test name without extension (used for log/wave naming)
TEST_NAME = $(basename $(TEST))
TEST_LOG  = $(LOG_DIR)/$(TOP)_$(TEST_NAME).log
TEST_WAVE = $(WAVE_DIR)/$(TOP)_$(TEST_NAME).vcd

RTL_SRCS  = $(wildcard $(SRC_DIR)/*.sv)
TB_SRC    = $(TB_DIR)/$(TB).cpp

SIM_EXE   = $(OBJ_DIR)/V$(TOP)

# ==============================================================================
#  Compiler Flags
# ==============================================================================

VERILATOR_FLAGS += -Wall --cc --exe
VERILATOR_FLAGS += --top-module $(TOP)
VERILATOR_FLAGS += -I$(INC_DIR) -I$(SRC_DIR)
VERILATOR_FLAGS += --Mdir $(OBJ_DIR)
VERILATOR_FLAGS += --trace
VERILATOR_FLAGS += -Wno-fatal -Wno-UNOPTFLAT
VERILATOR_FLAGS += -DTEST_FILE=\"$(TEST)\"   

CXX_FLAGS += -I$(OBJ_DIR)

# ==============================================================================
#  Build Targets
# ==============================================================================

.PHONY: all compile build run wave clean help

all: build

init:
	@mkdir -p $(OBJ_DIR) $(LOG_DIR) $(WAVE_DIR)

compile: init $(RTL_SRCS) $(TB_SRC)
	@echo "Running Verilator Compilation (TOP=$(TOP))..."
	$(VERILATOR) $(VERILATOR_FLAGS) src/includes/rv32_types_pkg.sv $(RTL_SRCS) $(TB_SRC)

build: compile
	@echo "Building Simulation Binary..."
	$(MAKE) -C $(OBJ_DIR) -f V$(TOP).mk V$(TOP)

run: build
	@echo "Running Simulation: TOP=$(TOP) TB=$(TB) TEST=$(TEST)"
	$(SIM_EXE) +TEST=$(TEST) +VERILATOR_LOGS=$(LOG_DIR) > $(TEST_LOG) 2>&1 || (cat $(TEST_LOG) && exit 1)
	@echo "Simulation finished. Log: $(TEST_LOG)"
	@if [ -f dumpfile.vcd ]; then \
		mv dumpfile.vcd $(TEST_WAVE); \
		echo "Waveform saved to $(TEST_WAVE)"; \
	fi

wave:
	@echo "Opening $(TEST_WAVE) in GTKWave..."
	@if [ -f $(TEST_WAVE) ]; then \
		gtkwave $(TEST_WAVE) > /dev/null 2>&1 & \
	else \
		echo "Error: $(TEST_WAVE) not found. Run 'make run TEST=$(TEST)' first."; \
	fi

clean:
	@echo "Cleaning simulation workspace..."
	rm -rf $(OBJ_DIR) $(LOG_DIR) $(WAVE_DIR)
	rm -f *.vcd *.vcd.idx

help:
	@echo "Usage: make [target] [TOP=module] [TB=testbench] [TEST=program.hex]"
	@echo ""
	@echo "Examples:"
	@echo "  make run TOP=cpu TB=cpu_tb TEST=/test/hex/test.hex"
	@echo "  make wave TOP=cpu TEST=test.hex"
	@echo ""
	@echo "Targets: all compile build run wave clean help"
