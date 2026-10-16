# Release Checklist

Use this checklist before tagging a version or distributing a build outside a development environment.

## Source and test validation

- [ ] Review all changes and confirm that no local workspace state, credentials, provisioning profiles, signing certificates, or generated build products are committed.
- [ ] Run `swift test` from the repository root.
- [ ] Run `swift test -c release` for a release configuration check.
- [ ] Open `LexiDFA.xcodeproj` in Xcode 26 or newer.
- [ ] Build for a generic iOS Simulator with signing disabled, then run the app on a simulator.
- [ ] Smoke-test Scanner, DFA, Trace, Tokens, and Lab in light and dark appearance.
- [ ] Verify scanning examples, unknown/error tokens, source-to-trace selection, trace playback, and benchmark output verification.
- [ ] Check VoiceOver labels, dynamic type, and the smallest supported iPhone layout.

## Version and signing

- [ ] Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project.
- [ ] Confirm that the bundle identifier is registered to the publishing team. The repository default is `com.amiraliyazdani.lexidfa`; change it if that identifier is not available to the account.
- [ ] Select the correct Apple Developer team in **Signing & Capabilities**.
- [ ] Build an Archive for a generic iOS device and resolve all signing/archive warnings.
- [ ] Validate the archive in Xcode Organizer before uploading it to App Store Connect or distributing it through another supported channel.

## Store metadata and privacy

- [ ] Capture real screenshots from the final build for every required device class.
- [ ] Prepare an accurate description, keywords, support contact, and age rating.
- [ ] Confirm `PrivacyInfo.xcprivacy` is present in the archived app bundle and validate its contents in the archive.
- [ ] Review the App Privacy questionnaire based on the final binary and any services added later. Do not rely on the README alone as a substitute for the App Store privacy declarations.
- [ ] Add the published privacy-policy URL to App Store Connect after hosting `PRIVACY.md` at a stable public URL.
- [ ] Test the distributed build, not only the Debug build.
- [ ] Tag the validated source with a version tag and publish release notes.

## Command-line simulator build

The following checks the Xcode project without requiring an Apple signing identity:

```bash
xcodebuild \
  -project LexiDFA.xcodeproj \
  -scheme LexiDFA \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

This build check does not create a store-ready archive. Device distribution requires appropriate signing and provisioning.
