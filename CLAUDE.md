# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VoiceInk is a native macOS voice-to-text application that transcribes audio with high accuracy using local AI models. The app is built with SwiftUI and uses whisper.cpp for local transcription, with support for cloud-based models via multiple providers.

## Building and Testing

### Build Commands

**Standard build:**
```bash
xcodebuild -project VoiceInk.xcodeproj \
    -scheme VoiceInk \
    -configuration Release \
    build
```

**Build with tests:**
```bash
xcodebuild test \
    -project VoiceInk.xcodeproj \
    -scheme VoiceInk \
    -destination 'platform=macOS' \
    -derivedDataPath ./build \
    -skipPackagePluginValidation \
    -skipMacroValidation
```

**Note:** The `-derivedDataPath ./build` and `-skipPackagePluginValidation -skipMacroValidation` flags are required because FluidAudio uses unsafe build flags for LAPACK support.

### Running Tests

Run all tests:
```bash
xcodebuild test -project VoiceInk.xcodeproj -scheme VoiceInk -destination 'platform=macOS' -derivedDataPath ./build -skipPackagePluginValidation -skipMacroValidation
```

### Dependencies Setup

**whisper.cpp framework** (required for local Whisper models):
```bash
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
./build-xcframework.sh
```

Then add `build-apple/whisper.xcframework` to the Xcode project's "Frameworks, Libraries, and Embedded Content" section.

**Swift Package Dependencies:**
- FluidAudio (requires unsafe build flags enabled via WorkspaceSettings.xcsettings)
- Sparkle (auto-updates)
- KeyboardShortcuts
- LaunchAtLogin
- MediaRemoteAdapter
- Zip
- swift-atomics (required for thread-safe operations in WhisperState+LocalModelManager.swift)

## Architecture

### Core State Management

**WhisperState** (`VoiceInk/Whisper/WhisperState.swift`) - Central `@MainActor` observable object managing:
- Recording state machine (`idle` → `recording` → `transcribing` → `enhancing` → `idle`)
- Model loading and management (local Whisper models, cloud models, Parakeet models)
- Mini recorder visibility and panel management
- Audio device configuration

### Transcription Pipeline

All transcription services conform to the `TranscriptionService` protocol:

```swift
protocol TranscriptionService {
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String
}
```

**Implementations:**
- `LocalTranscriptionService` - Uses whisper.cpp for local Whisper models
- `ParakeetTranscriptionService` - Uses FluidAudio for Parakeet models (v2/v3)
- `NativeAppleTranscriptionService` - Uses Apple's Speech framework
- Cloud services in `Services/CloudTranscription/`:
  - `GroqTranscriptionService`
  - `GeminiTranscriptionService`
  - `DeepgramTranscriptionService`
  - `OpenAICompatibleTranscriptionService`
  - And others

### Power Mode System

Power Mode allows users to configure app-specific or URL-specific transcription settings.

**Key components:**
- `PowerModeConfig` - Model representing a power mode configuration (target app/URL, model, AI prompt, etc.)
- `PowerModeSessionManager` - Tracks active window and applies matching power mode
- `ActiveWindowService` - Monitors frontmost application
- `BrowserURLService` - Extracts URLs from supported browsers (Safari, Chrome, Firefox, Arc)

**Flow:** User switches apps → `ActiveWindowService` detects change → `PowerModeSessionManager` finds matching config → Settings auto-apply

### AI Enhancement

Post-transcription text enhancement via AI:

1. User speaks → transcribed to raw text
2. If AI mode enabled → `AIEnhancementService` processes text with selected prompt
3. `AIService` routes to provider (OpenAI, Anthropic, Gemini, Ollama, etc.)
4. `AIEnhancementOutputFilter` formats response based on selected mode (e.g., removes markdown code fences)

### Audio Recording

- `Recorder.swift` - Handles microphone input via AVAudioEngine
- `VoiceActivityDetector` - Detects speech vs silence for auto-stop
- `AudioDeviceManager` - Manages input device selection and configuration
- `MediaController` - Pauses/resumes media playback during recording

### Text Output

Multiple output destinations:
- `CursorPaster` - Simulates keyboard input to paste at cursor
- `ClipboardManager` - Copies to system clipboard
- `PasteEligibilityService` - Determines if auto-paste is safe based on active app

### Models & Data

- `Transcription` - SwiftData model for transcription history
- `TranscriptionModel` - Protocol for all transcription models (local/cloud)
- `WhisperModel` - Local whisper.cpp model representation
- `CustomPrompt` - User-defined AI prompts
- `PowerModeConfig` - Power mode configurations

## Key Swift Package Dependencies

### FluidAudio Integration

FluidAudio is used for Parakeet model support and requires special handling:

1. **Unsafe build flags:** FluidAudio uses `-DACCELERATE_NEW_LAPACK` and `-DACCELERATE_LAPACK_ILP64` for LAPACK support
2. **WorkspaceSettings required:** `VoiceInk.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` must have `IDEPackageSupportUnsafeFlagsAllowed = true`
3. **API compatibility:** Use `VadConfig(defaultThreshold:)` not `VadConfig(threshold:)` with recent FluidAudio versions

### Package.resolved Tracking

FluidAudio tracks the `main` branch (not a version tag) to get latest ESpeakNG framework fixes. This means:
- The project uses branch-based dependency resolution for FluidAudio
- Other dependencies (KeyboardShortcuts, Sparkle) use semantic versioning
- Package.resolved lock file should be committed to ensure consistent builds

## UI Structure

- `ContentView.swift` - Main app container with tab navigation
- `Views/Recorder/` - Mini recorder and notch recorder panels
- `Views/AI Models/` - Model management and download UI
- `Views/Settings/` - Settings tabs (general, models, power mode, shortcuts, etc.)
- `Views/Dictionary/` - Custom dictionary and word replacement
- `Views/Metrics/` - Usage analytics and performance tracking
- `Views/Onboarding/` - First-run setup flow

## Important Patterns

### @MainActor Isolation

Most view models and UI-related state are `@MainActor` isolated. Audio processing and transcription happen on background actors/queues.

### Notification Center Usage

Key notifications:
- `.navigateToDestination` - Navigate to specific tab
- `.openFileForTranscription` - Open audio file for transcription
- `.modelDownloadProgress` - Model download updates

### UserDefaults Keys

Settings are stored in UserDefaults with keys like:
- `"IsMenuBarOnly"` - Run as menu bar app
- `"RecorderType"` - Mini vs notch recorder
- `"IsVADEnabled"` - Voice activity detection
- Many more in `UserDefaultsManager.swift`

## Contributing Requirements

Before submitting a PR:

1. **Discuss first:** Open an issue to propose changes before implementing
2. **Run tests:** All tests must pass (`xcodebuild test ...`)
3. **Follow Swift style guidelines**
4. **Test with whisper.cpp:** Ensure local models still work
5. **Test FluidAudio integration:** If touching Parakeet-related code

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

## Build Script for Development

A `build_and_install.sh` script is available that automates the build process with proper flags:

```bash
#!/bin/bash
set -e

xcodebuild -project VoiceInk.xcodeproj \
    -scheme VoiceInk \
    -configuration Release \
    -derivedDataPath ./build \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    -allowProvisioningUpdates \
    clean build

# Sign frameworks and app
for framework in build/Build/Products/Release/VoiceInk.app/Contents/Frameworks/*.framework; do
    codesign --force --sign - "$framework"
done
codesign --force --sign - build/Build/Products/Release/VoiceInk.app

# Install to /Applications
rm -rf /Applications/VoiceInk.app
cp -r build/Build/Products/Release/VoiceInk.app /Applications/
xattr -cr /Applications/VoiceInk.app
```

This script handles:
- Building with unsafe flags enabled
- Code signing frameworks (including ESpeakNG)
- Installing to /Applications
- Removing quarantine attributes

## Updating Swift Package Dependencies

To update dependencies (FluidAudio, Sparkle, KeyboardShortcuts, etc.):

**Recommended - Via Xcode GUI:**
1. Open `VoiceInk.xcodeproj` in Xcode
2. File > Packages > Update to Latest Package Versions

**If GUI doesn't work - Clear caches:**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/VoiceInk-*/SourcePackages
rm -rf ~/Library/Caches/org.swift.swiftpm
xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -resolvePackageDependencies
```

## Common Gotchas

1. **Build failures with FluidAudio:** Ensure `WorkspaceSettings.xcsettings` exists with `IDEPackageSupportUnsafeFlagsAllowed = true`
2. **whisper.cpp not found:** The xcframework must be manually built and added to the project
3. **Command-line builds fail, Xcode succeeds:** Use `-skipPackagePluginValidation -skipMacroValidation` flags with xcodebuild
4. **Tests fail with unsafe flags error:** Use `-derivedDataPath ./build` to use custom build directory
5. **Package.resolved not updating:** Clear SPM caches or use Xcode GUI to update packages
6. **Power Mode not working:** Requires Accessibility permissions granted in System Settings
7. **Missing swift-atomics dependency:** If build fails with "Unable to find module dependency: 'Atomics'", update Swift packages via Xcode GUI (File > Packages > Update to Latest Package Versions). Command-line package resolution may not fetch transitive dependencies correctly.
8. **Build script needs -allowProvisioningUpdates:** Add this flag to xcodebuild for automatic code signing with personal Apple ID

## Syncing Fork with Upstream

When syncing a fork of VoiceInk with upstream:

**Remote configuration:**
```bash
git remote add upstream https://github.com/Beingpax/VoiceInk.git
```

**Proper sync workflow:**
```bash
# 1. Update fork's main branch from upstream
git checkout main
git fetch upstream
git merge upstream/main
git push origin main

# 2. Merge fork's main into personal dev branch
git checkout personal/dev
git merge main
git push origin personal/dev
```

**Resolve bundle ID conflicts manually:** When merging, project.pbxproj will conflict. **DO NOT use `git checkout --ours`** - it discards ALL upstream changes. Instead:
1. Let the conflict occur naturally
2. Manually edit conflicted sections to:
   - Keep: `PRODUCT_BUNDLE_IDENTIFIER = com.antonlvovych.VoiceInk`
   - Take: `MARKETING_VERSION = 1.61` (or latest)
   - Take: `CURRENT_PROJECT_VERSION = 161` (or latest)
   - Take: All other upstream changes
3. Stage resolved file and commit

**Why `git checkout --ours` fails:** Takes entire file from your branch, losing upstream changes like CURRENT_PROJECT_VERSION updates that don't conflict with bundle ID.

**Why this workflow:** Keeps fork's main branch in sync with upstream main, making it easier to create PRs back to upstream and maintain a clean fork history.

**Version tag gotcha:** Git tags may point to commits BEFORE the actual version bump. For v1.61, the tag points to a commit with version 1.60 in project.pbxproj. The version update happened in a later commit (e5e194d). Merge upstream/main instead of tags to get correct version.
