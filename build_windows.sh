#!/bin/bash

# ===== (1) Extract version from pubspec.yaml =====
VERSION=$(grep 'version:' pubspec.yaml | awk '{print $2}' | tr -d '"')
if [ -z "$VERSION" ]; then
    echo "❌ Failed to extract version from pubspec.yaml"
    exit 1
fi
echo "✅ Detected version: $VERSION"

# ===== (2) Build Flutter Windows release =====
echo "⚙️  Building Flutter Windows release..."
flutter build windows --release

if [ $? -ne 0 ]; then
    echo "❌ Flutter build failed. Aborting."
    exit 1
fi

# ===== (3) Run Enigma Virtual Box (EVB) on the project file =====
EVB_PROJECT="./windows/Reverbio_portable_creator.evb"                                       # Replace with your .evb file path
EVB_CONSOLE="C:/Program Files (x86)/Enigma Virtual Box/enigmavbconsole.exe"                 # Path to EVB console (adjust if needed)
EVB_OUTPUT="./build/windows/x64/runner/Release/reverbio_win_x64_portable.exe"               # EVB's default output (from .evb file)
FINAL_OUTPUT="./build/windows/x64/runner/Release/reverbio_${VERSION}_win_x64_portable.exe"  # Desired versioned filename

echo "⚙️  Running Enigma Virtual Box on $EVB_PROJECT..."
"$EVB_CONSOLE" "$EVB_PROJECT"

if [ $? -ne 0 ]; then
    echo "❌ EVB processing failed."
    exit 1
fi

echo "✅ Build and virtualization complete!"

# ===== (4) Rename the output with version =====
if [ -f "$EVB_OUTPUT" ]; then
    mv "$EVB_OUTPUT" "$FINAL_OUTPUT"
    echo "✅ Success! Final executable: $FINAL_OUTPUT"
else
    echo "❌ EVB output not found: $EVB_OUTPUT"
    exit 1
fi