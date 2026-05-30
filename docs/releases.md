# IPA releases

NightFlix has two GitHub Actions release flows:

- Stable releases: push a version tag like `v1.0.0`, or run **Stable IPA Release** manually with that tag name. The workflow publishes a normal GitHub Release and attaches the IPA.
- Nightly releases: run every day at `02:17 UTC`, and can also be run manually. The workflow publishes a prerelease named `nightly-YYYYMMDD-SHA` and attaches the IPA.

Both workflows also upload the same files as GitHub Actions artifacts.

## Required signing secrets

Configure these repository secrets before running either workflow:

- `IOS_BUILD_CERTIFICATE_BASE64`: base64-encoded `.p12` signing certificate.
- `IOS_P12_PASSWORD`: password for the `.p12` certificate.
- `IOS_PROVISION_PROFILE_BASE64`: base64-encoded `.mobileprovision` profile for `FrizzleM.NightFlix`.
- `IOS_KEYCHAIN_PASSWORD`: any strong password used for the temporary CI keychain.

Optional repository variables:

- `IOS_DEVELOPMENT_TEAM`: overrides the team ID parsed from the provisioning profile.
- `IOS_STABLE_EXPORT_METHOD`: defaults to `debugging`, which works with an Xcode-managed iOS Team Provisioning Profile. Set this to `release-testing` when you provide an Ad Hoc distribution profile.
- `IOS_NIGHTLY_EXPORT_METHOD`: defaults to `debugging`, which works with an Xcode-managed iOS Team Provisioning Profile. Set this to `release-testing` when you provide an Ad Hoc distribution profile.
- `XCODE_APP`: selects a specific installed Xcode app as it appears under `/Applications`. Defaults to `Xcode_26.5.app` on the `macos-26` runner.

The build script also accepts older export method names and maps `ad-hoc` to `release-testing`, `development` to `debugging`, and `app-store` to `app-store-connect`.

On macOS, you can encode files for secrets with:

```bash
base64 -i certificate.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
```
