# Building the Valentine disk image

Run from a logged-in macOS desktop with Xcode and `create-dmg` available (`brew install create-dmg`).

```sh
./create-dmg-release.sh
./create-dmg-release.sh /path/to/Valentine.app
./create-dmg-release.sh /path/to/Valentine.app /path/to/output.dmg
```

### Features

1. **Automatic Detection**:
   - If no app path is provided, the script automatically searches for `Valentine.app` in the project root or in `DerivedData`.
2. **Versioned Naming**:
   - Automatically extracts version, build, and architecture from the application bundle (`Info.plist` and `lipo -archs`).
   - Default output: `dist/valentine_{version}_{build}_{architecture}.dmg` (e.g. `dist/valentine_1.3_004_arm64.dmg`).
3. **Interactive EULA License Agreement**:
   - Embeds the project's `LICENSE` file into the disk image via Apple's native SLA/EULA mechanism.
   - When opened, macOS displays the full license terms with "Agree" / "Disagree" buttons before mounting.
4. **Light Theme Liquid Glass Finder Layout**:
   - Packaged as a multi-resolution Retina TIFF (`preview/dmg_background.tiff`) using `tiffutil -cathidpicheck` to fit the 660 × 440 window edge-to-edge.
   - Frosted glass pedestals framing the app and Applications icons with dark typography for optimal contrast.
   - Bottom Liquid Glass pill badge: "Drag here to install".
