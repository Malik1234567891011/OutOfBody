#!/bin/zsh
# Build (arm64 simulator only) and install/launch on the booted simulator.
set -e
cd "${0:A:h}"
SIM=${SIM:-booted}
xcodebuild -project OutOfBody.xcodeproj -scheme OutOfBody -destination "platform=iOS Simulator,${DEST:-name=iPhone 17}" \
  -derivedDataPath build ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build -quiet
xcrun simctl install $SIM build/Build/Products/Debug-iphonesimulator/OutOfBody.app
[[ -n "$NOLAUNCH" ]] || xcrun simctl launch $SIM com.malikshourbaji.outofbody
