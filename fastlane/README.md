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

### ios validate

```sh
[bundle exec] fastlane ios validate
```

Read-only: prüft API-Key + findet die App

### ios fetch_profile

```sh
[bundle exec] fastlane ios fetch_profile
```

Fetch App Store provisioning profile for ShipTrip

### ios upload_testflight

```sh
[bundle exec] fastlane ios upload_testflight
```

Upload IPA to TestFlight

### ios prepare_app_store

```sh
[bundle exec] fastlane ios prepare_app_store
```

Prepare App Store Connect 1.7.0, excluding app preview videos

### ios sync_worldwide_availability

```sh
[bundle exec] fastlane ios sync_worldwide_availability
```

Enable and verify all current App Store territories

### ios repair_app_store_version

```sh
[bundle exec] fastlane ios repair_app_store_version
```

Repair duplicate screenshots and select build 23

### ios sync_privacy_urls

```sh
[bundle exec] fastlane ios sync_privacy_urls
```

Update App Store privacy URLs from the prepared localized metadata

### ios verify_privacy_urls

```sh
[bundle exec] fastlane ios verify_privacy_urls
```

Read-only: verify localized App Store privacy URLs

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
