# Finamp Night iOS signing

Finamp Night uses the explicit bundle identifier `com.davidjpramsay.finampnight`
and Apple development team `9TZPXJ6JGH`, so it installs alongside the official
Finamp TestFlight app.

Apple treats CarPlay Audio as a managed capability. Until Apple grants that
capability to this App ID:

- iPhone Debug builds use `Runner/Runner.PhoneOnly.entitlements` and can be
  installed for phone UI testing without CarPlay.
- Simulator Debug builds, Profile builds, and Release builds retain
  `Runner/Runner.entitlements`, which declares CarPlay Audio and Siri.

After Apple approves CarPlay Audio and a new provisioning profile has been
created, remove the `CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]` override from the
Runner Debug build configuration if physical-device CarPlay debugging is
required.

Local iOS builds require CocoaPods and Rust because several plugins do not yet
support Swift Package Manager and `flutter_discord_rpc` compiles a Rust
component.
