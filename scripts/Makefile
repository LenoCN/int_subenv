# Makefile for IOSUB Normal Interrupt Mapping Extraction

# Default Excel file (can be overridden)
EXCEL_FILE ?= interrupt_table.xlsx
OUTPUT_PREFIX ?= iosub_normal_mapping

# Python interpreter
PYTHON ?= python3

# Check if Excel file exists
check-excel:
	@if [ ! -f "$(EXCEL_FILE)" ]; then \
		echo "Error: Excel file '$(EXCEL_FILE)' not found"; \
		echo "Please specify the correct file: make extract EXCEL_FILE=your_file.xlsx"; \
		exit 1; \
	fi

# Install required dependencies
install-deps:
	@echo "Installing required Python packages..."
	$(PYTHON) -m pip install pandas openpyxl

# Test the extraction with sample data
test:
	@echo "Running extraction test with sample data..."
	$(PYTHON) test_extraction.py

# Extract mapping from Excel file
extract: check-excel
	@echo "Extracting IOSUB normal interrupt mapping from: $(EXCEL_FILE)"
	@echo "Output prefix: $(OUTPUT_PREFIX)"
	$(PYTHON) extract_iosub_registers.py $(EXCEL_FILE) $(OUTPUT_PREFIX)
	@echo ""
	@echo "Generated files:"
	@ls -la $(OUTPUT_PREFIX).*

# Extract with verbose output
extract-verbose: check-excel
	@echo "Extracting with verbose output..."
	$(PYTHON) extract_iosub_normal_mapping.py $(EXCEL_FILE) -o $(OUTPUT_PREFIX).md -v

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	rm -f iosub_normal_mapping.*
	rm -f test_iosub_mapping.*
	rm -f sample_iosub_interrupts.xlsx

# Show help
help:
	@echo "IOSUB Normal Interrupt Mapping Extraction"
	@echo "=========================================="
	@echo ""
	@echo "Available targets:"
	@echo "  install-deps    - Install required Python packages"
	@echo "  test           - Test extraction with sample data"
	@echo "  extract        - Extract mapping from Excel file"
	@echo "  extract-verbose - Extract with verbose output"
	@echo "  clean          - Clean generated files"
	@echo "  help           - Show this help"
	@echo ""
	@echo "Usage examples:"
	@echo "  make test"
	@echo "  make extract EXCEL_FILE=my_interrupts.xlsx"
	@echo "  make extract EXCEL_FILE=interrupts.xlsx OUTPUT_PREFIX=my_mapping"
	@echo ""
	@echo "Environment variables:"
	@echo "  EXCEL_FILE     - Path to Excel interrupt table (default: interrupt_table.xlsx)"
	@echo "  OUTPUT_PREFIX  - Prefix for output files (default: iosub_normal_mapping)"
	@echo "  PYTHON         - Python interpreter (default: python3)"

# Default target
.DEFAULT_GOAL := help

.PHONY: check-excel install-deps test extract extract-verbose clean help
