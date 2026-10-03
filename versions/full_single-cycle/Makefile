# Default configuration variables (can be overridden from command line)
TOP_MODULE ?= top
TB_FILE    ?= top_tb.cpp
DESIGN     ?= $(TOP_MODULE).sv

# Test binary selection
TEST ?= program.hex

# Verilator compilation flags
VERILATOR  = verilator
VFLAGS     = --cc --exe --top-module $(TOP_MODULE) -j $(shell nproc) --trace

# Output build directory
BUILD_DIR  = obj_dir
MAKEFILE   = V$(TOP_MODULE).mk
EXECUTABLE = ./$(BUILD_DIR)/V$(TOP_MODULE)

.PHONY: all clean run build

# Default target: clean, build, and run the simulation
all: clean build run

# Clean the previous build directory
clean:
	@echo "Cleaning up previous build files..."
	@rm -rf $(BUILD_DIR)

# Build the simulation executable
build: $(BUILD_DIR)/$(MAKEFILE)
	@echo "Building the simulation..."
	@$(MAKE) -C $(BUILD_DIR) -f $(MAKEFILE)

# Generate C++ Makefile using Verilator
$(BUILD_DIR)/$(MAKEFILE): $(DESIGN) $(TB_FILE)
	@echo "Running Verilator for $(TOP_MODULE)"
	-@$(VERILATOR) $(VFLAGS) $(DESIGN) $(TB_FILE)

# Run the compiled simulation executable with the selected HEX file
run:
	@echo "Running the simulation with: $(TEST)..."
	@$(EXECUTABLE) +HEX_FILE=$(TEST)
