fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac setup

```sh
[bundle exec] fastlane mac setup
```

Register app bundle ID and create App ID in Developer Portal

NOTE: Run this interactively — produce requires Apple ID login

### mac metadata

```sh
[bundle exec] fastlane mac metadata
```

Upload App Store metadata (name, description, keywords, etc.)

### mac build

```sh
[bundle exec] fastlane mac build
```

Build the app for App Store distribution

### mac beta

```sh
[bundle exec] fastlane mac beta
```

Build and upload to TestFlight

### mac release

```sh
[bundle exec] fastlane mac release
```

Build, upload binary, and submit for App Store review

### mac screenshots

```sh
[bundle exec] fastlane mac screenshots
```

Capture and upload screenshots

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
