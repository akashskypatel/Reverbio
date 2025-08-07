#!/bin/sh
# Script to set up ADB forwarding and launch Desktop Head Unit

echo "Setting up ADB port forwarding..."
adb forward tcp:5277 tcp:5277

if [ $? -ne 0 ]; then
    echo "Failed to set up ADB port forwarding"
    exit 1
fi

echo "Starting Desktop Head Unit..."
"$LOCALAPPDATA/Android/Sdk/extras/google/auto/desktop-head-unit.exe"

if [ $? -ne 0 ]; then
    echo "Failed to start Desktop Head Unit"
    exit 1
fi

echo "Desktop Head Unit started successfully"