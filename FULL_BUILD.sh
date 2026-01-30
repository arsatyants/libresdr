#!/bin/bash

# Full build script for LibreSDR firmware
# Handles complete build process with automatic fixes

set -e  # Exit on error

# Set Vivado path
export VIVADO_SETTINGS=/media/arsatyants/vivado/vivado/Vivado/2022.2/settings64.sh

echo "======================================"
echo "   LibreSDR Full Build Script v1.0   "
echo "======================================"
echo ""

# Get script directory and ensure we're in the right place
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if we're in libresdr2 root or plutosdr-fw_0.38_libre subdirectory
if [ -f "$SCRIPT_DIR/plutosdr-fw_0.38_libre/Makefile" ]; then
    # Script is in libresdr2 root, cd to firmware directory
    cd "$SCRIPT_DIR/plutosdr-fw_0.38_libre"
    echo "Running from libresdr2 root, changing to plutosdr-fw_0.38_libre/"
elif [ -f "$SCRIPT_DIR/Makefile" ]; then
    # Script is already in plutosdr-fw_0.38_libre
    cd "$SCRIPT_DIR"
    echo "Running from plutosdr-fw_0.38_libre directory"
else
    echo "ERROR: Cannot find plutosdr-fw_0.38_libre directory with Makefile"
    exit 1
fi

# Verify we're in the right directory
if [ ! -f "Makefile" ] || [ ! -d "buildroot" ]; then
    echo "ERROR: Cannot find Makefile or buildroot directory"
    exit 1
fi

echo "Working directory: $(pwd)"
echo ""

# Check if Vivado settings path is set
if [ -z "$VIVADO_SETTINGS" ]; then
    export VIVADO_SETTINGS=/media/arsatyants/vivado/vivado/Vivado/2022.2/settings64.sh
    echo "VIVADO_SETTINGS not set, using default: $VIVADO_SETTINGS"
fi

if [ ! -f "$VIVADO_SETTINGS" ]; then
    echo "ERROR: Vivado settings file not found at: $VIVADO_SETTINGS"
    echo "Please set VIVADO_SETTINGS environment variable to point to your Vivado installation"
    echo "Example: export VIVADO_SETTINGS=/path/to/Vivado/2022.2/settings64.sh"
    exit 1
fi

# Set target
export TARGET=libre
echo "TARGET: $TARGET"
echo "Vivado: $VIVADO_SETTINGS"
echo ""

# Apply buildroot package hash fixes (git checkout creates different hashes)
echo "=== Applying buildroot package hash fixes ==="
HASH_FILE1="buildroot/package/ad936x_ref_cal/ad936x_ref_cal.hash"
if [ -f "$HASH_FILE1" ]; then
    # Update hash to match current git checkout
    sed -i 's/sha256 26aedd8021fa939ab2f53e55904d869207265242fef7ad86aa4673e219b7cbef/sha256 4814915de63d975807e918df82bb86021d0e78839e8cc4116a36476d0b33180c/' "$HASH_FILE1" 2>/dev/null || true
    echo "✓ ad936x_ref_cal hash updated"
else
    echo "⚠ ad936x_ref_cal hash file not found"
fi

HASH_FILE2="buildroot/package/libiio/libiio.hash"
if [ -f "$HASH_FILE2" ]; then
    # Update libiio hash to match current git checkout
    sed -i 's/sha256 e791ad1cf35aef08fc6e2b6b0dcdd1cc21d36cf287d81fa14adb088c6c1d4c49/sha256 865fe496624bebc7c4266bf157fb4b5ec851b5f929d2571ec73846e4f317cf46/' "$HASH_FILE2" 2>/dev/null || true
    echo "✓ libiio hash updated"
else
    echo "⚠ libiio hash file not found"
fi
echo ""

# Clean previous build
echo "=== Cleaning previous build ==="
make clean 2>&1 | tail -5
echo "✓ Clean complete"
echo ""

# Start build
BUILD_LOG="build_full.log"
echo "=== Starting firmware build ==="
echo "This will take approximately 15-20 minutes..."
echo "Build log: $BUILD_LOG"
echo ""
echo "Build started at: $(date)"
START_TIME=$(date +%s)

# Run make with output to both console and log
if make 2>&1 | tee "$BUILD_LOG"; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    echo ""
    echo "======================================"
    echo "   BUILD SUCCESSFUL!                  "
    echo "======================================"
    echo "Build time: ${MINUTES}m ${SECONDS}s"
    echo "Build completed at: $(date)"
    echo ""
    echo "Build artifacts:"
    ls -lh build/*.frm build/boot.dfu 2>/dev/null || echo "  Checking build/ directory..."
    ls -lh build/*.bin build/*.itb 2>/dev/null || true
    echo ""
    echo "To create SD card image, run:"
    echo "  cd plutosdr-fw_0.38_libre && make sdimg   # (or: make sdimg from plutosdr-fw_0.38_libre/)"
    echo ""
    echo "To flash via DFU, run:"
    echo "  sudo dfu-util -a firmware.dfu -D build/libre.dfu"
    echo ""
else
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    echo ""
    echo "======================================"
    echo "   BUILD FAILED!                      "
    echo "======================================"
    echo "Build time: ${MINUTES}m ${SECONDS}s"
    echo "Failed at: $(date)"
    echo ""
    echo "Check the log file for details:"
    echo "  tail -100 $BUILD_LOG"
    echo ""
    echo "Common issues:"
    echo "  - Hash mismatch: Update package hash files (already attempted)"
    echo "  - Network issues: Check internet connection"
    echo "  - Vivado not found: Check VIVADO_SETTINGS path"
    echo ""
    exit 1
fi
