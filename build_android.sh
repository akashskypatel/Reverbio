#!/bin/bash

# ===== (1) Build Flutter Android release =====
echo "⚙️  Building Flutter Android release..."
flutter build apk --release

if [ $? -ne 0 ]; then
    echo "❌ Flutter build failed. Aborting."
    exit 1
fi
