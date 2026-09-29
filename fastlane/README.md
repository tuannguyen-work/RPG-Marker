fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios auth_test

```sh
[bundle exec] fastlane ios auth_test
```

Check the API key works and the app record exists. Read-only.

### ios build

```sh
[bundle exec] fastlane ios build
```

Build a signed App Store IPA into fastlane/build (build number = latest TestFlight build + 1)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload App Store text (fastlane/metadata) without a build or screenshots

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture App Store screenshots on the iPhone 17 Pro Max simulator (6.9") into fastlane/screenshots

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload screenshots from fastlane/screenshots

### ios release

```sh
[bundle exec] fastlane ios release
```

Submit the latest TestFlight build, with metadata and screenshots, for App Review

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
