# Car Plist Editor

SwiftUI iOS app for reading the game's plist, listing recognized `CAR_n` entries, adding one vehicle record, and exporting a plist with the same suggested filename as the imported file.

## Build an IPA with GitHub Actions

1. Upload the **contents** of this folder to the root of a GitHub repository (not the ZIP file itself).
2. Open the repository's **Actions** tab.
3. Select **Build IPA** and choose **Run workflow**. A push to `main` or `master` also starts a build.
4. When the run completes, download the `CarPlistEditor-IPA` artifact and extract `CarPlistEditor.ipa`.

The workflow uses GitHub-hosted macOS and XcodeGen to generate the Xcode project. Code signing is disabled; the resulting IPA is an unsigned build intended for the user's sideloading workflow. Installation compatibility depends on the signing/install method and device environment.

## Project layout

- `.github/workflows/build.yml` — GitHub Actions IPA build workflow
- `project.yml` — XcodeGen project definition
- `Sources/CarPlistEditorApp.swift` — app entry point
- `Sources/ContentView.swift` — import, vehicle list, add, export UI
- `Sources/CarPlistCrypto.swift` — plist decoding/encoding and XXHash32
- `Sources/PlistDocument.swift` — iOS file document exporter
