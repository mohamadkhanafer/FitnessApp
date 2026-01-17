#!/bin/bash
set -e

# VitalBrief build and run script for iOS Simulator

SCHEME="VitalBrief"
DEVICE="iPhone 15"
BUILD_DIR="build"
PROJECT_DIR="."

echo "🚀 VitalBrief iOS Build & Run"
echo "=============================="

# Step 1: Launch simulator
echo "📱 Launching iOS Simulator ($DEVICE)..."
open -a Simulator
sleep 3

# Step 2: Build for simulator
echo "🔨 Building $SCHEME for $DEVICE..."
mkdir -p $BUILD_DIR
xcodebuild build \
  -scheme $SCHEME \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath $BUILD_DIR \
  CONFIGURATION=Debug \
  | grep -E "error:|warning:|Build complete|BUILD"

# Step 3: Find and install the app
echo "📦 Installing app on simulator..."
APP_PATH=$(find $BUILD_DIR -name "*.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
  echo "❌ Error: Could not find .app bundle"
  exit 1
fi

echo "Found app at: $APP_PATH"

# Step 4: Get simulator UDID
SIMULATOR_UDID=$(xcrun simctl list devices available | grep "$DEVICE" | tail -1 | awk '{print $NF}' | tr -d '()')

if [ -z "$SIMULATOR_UDID" ]; then
  echo "❌ Error: Could not find simulator UDID"
  exit 1
fi

echo "Simulator UDID: $SIMULATOR_UDID"

# Step 5: Install app
echo "⚙️  Installing app..."
xcrun simctl install $SIMULATOR_UDID "$APP_PATH"

# Step 6: Get bundle ID
BUNDLE_ID=$(defaults read "$APP_PATH/Info.plist" CFBundleIdentifier 2>/dev/null || echo "com.vitalbrief.app")

# Step 7: Launch app
echo "✅ Launching VitalBrief..."
xcrun simctl launch $SIMULATOR_UDID $BUNDLE_ID

echo "🎉 Done! VitalBrief should now be running on the simulator."
