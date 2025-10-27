#!/bin/bash

set -e

echo "========================================="
echo "VoiceInk Build & Install Script"
echo "========================================="
echo "Using FluidAudio v0.7.5+ (ESpeakNG typo fixed!)"

# Build the app
echo ""
echo "[1/5] Building VoiceInk (Release)..."
xcodebuild -project VoiceInk.xcodeproj \
    -scheme VoiceInk \
    -configuration Release \
    -derivedDataPath ./build \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    clean build 2>&1 | grep -E "^\*\*|error:|warning:" || true

# Verify build succeeded
if [ ! -d "build/Build/Products/Release/VoiceInk.app" ]; then
    echo "❌ Build failed - VoiceInk.app not found"
    exit 1
fi
echo "  ✓ Build succeeded"

# Sign frameworks
echo ""
echo "[2/5] Signing frameworks..."
for framework in build/Build/Products/Release/VoiceInk.app/Contents/Frameworks/*.framework; do
    framework_name=$(basename "$framework")
    echo "  → Signing $framework_name"
    codesign --force --sign - "$framework" 2>/dev/null || true
done
echo "  ✓ Frameworks signed"

# Sign main app
echo ""
echo "[3/5] Signing app bundle..."
codesign --force --sign - build/Build/Products/Release/VoiceInk.app/Contents/MacOS/VoiceInk 2>/dev/null
codesign --force --sign - build/Build/Products/Release/VoiceInk.app 2>/dev/null
echo "  ✓ App signed"

# Install to Applications
echo ""
echo "[4/5] Installing to /Applications..."
if [ -d "/Applications/VoiceInk.app" ]; then
    echo "  → Removing old version"
    rm -rf /Applications/VoiceInk.app
fi
cp -r build/Build/Products/Release/VoiceInk.app /Applications/
xattr -cr /Applications/VoiceInk.app
echo "  ✓ Installed to /Applications/VoiceInk.app"

# Verify installation
echo ""
echo "[5/5] Verifying installation..."
if [ -f "/Applications/VoiceInk.app/Contents/MacOS/VoiceInk" ]; then
    echo "  ✓ Installation verified"
else
    echo "  ❌ Installation failed"
    exit 1
fi

echo ""
echo "========================================="
echo "✅ SUCCESS! VoiceInk is ready to use"
echo "========================================="
echo ""
echo "Launch with:"
echo "  open /Applications/VoiceInk.app"
echo ""
