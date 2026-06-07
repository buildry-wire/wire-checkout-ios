# Releasing wire-checkout-ios (WireCheckout)

Distribution is primarily via **Swift Package Manager** (a git tag is all SPM
needs) and optionally **CocoaPods**.

## Cut a release

1. Bump the version in `WireCheckout.podspec` (`s.version`) and move the
   changelog items from `## [Unreleased]` to `## [x.y.z] - YYYY-MM-DD`.
2. Commit on `main`, then tag and push:
   ```bash
   git tag vX.Y.Z   # must equal the podspec version
   git push origin vX.Y.Z
   ```
3. Pushing the tag triggers `.github/workflows/release.yml`, which creates a
   GitHub Release. **No artifact upload is required for SPM** — consumers
   resolve the tag directly.

## Verify (Swift Package Manager)

Consumers add the repo URL and pin the tag:

```swift
.package(url: "https://github.com/buildry-wire/wire-checkout-ios", from: "X.Y.Z")
```

## Optional: publish to CocoaPods

CocoaPods Trunk requires a one-time session registered to the maintainer's
email (cannot be fully automated):

```bash
# One-time, on the maintainer's machine:
pod trunk register you@example.com 'Your Name'   # confirm via the email link

# Per release, after the tag is pushed:
pod spec lint WireCheckout.podspec --allow-warnings
pod trunk push WireCheckout.podspec --allow-warnings
```

`pod trunk push` reads `s.version` and the matching `vX.Y.Z` git tag from the
podspec's `:source`. Never commit a Trunk token.
