#!/bin/bash
# Build and open Pause dev app

set -e

echo "Building Pause..."
xcodebuild -project Pause.xcodeproj -scheme Pause -configuration Debug build 2>&1 | grep -E "(BUILD|error:)" | tail -5

echo "Copying app..."
cp -R ~/Library/Developer/Xcode/DerivedData/Pause-*/Build/Products/Debug/Pause.app .

echo "Opening app..."
open Pause.app
