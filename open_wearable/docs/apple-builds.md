# Apple builds and releases

GitHub Actions builds iOS and macOS on standard `macos-15` runners with Xcode
26.2 and the Flutter version pinned in `.flutter_version`. Android, Linux,
Windows, and web continue using their existing GitHub runners.

## Pull requests

**Build PR Artifacts** compiles both Apple platforms without signing credentials.
These artifacts validate compilation; the unsigned iOS app cannot be installed
on a physical iPhone. Fork PRs do not receive Apple secrets.

## TestFlight

**Apple TestFlight** archives both platforms on each push to `main`, then submits
for Beta App Review when required and assigns the builds to the existing
**Internal Testing** and **External Testing** groups. This preserves the old
Xcode Cloud main-branch distribution settings, including automatic notification
when Apple makes an external build available. It does not submit a public App
Store release.

The workflow can also be run manually against a chosen ref. Manual runs default
to upload-only validation; enable `distribute` to send the build to those groups.

## App Store releases

Use **Release All Platforms**, **Apple App Store Build and Submit**, or either
platform's individual release workflow. The workflows keep the existing
immutable version tag and release-note validation. Build scripts come from the
workflow revision, while app source comes from the release tag, so a CI fix can
release an existing tag without changing its contents.

The GitHub Mac archives the app, then Xcode signs and uploads it directly to App
Store Connect. Automatic signing uses the existing API key and Apple's managed
distribution certificates. This signing service does not consume Xcode Cloud
build hours. The key must have access to signing resources and app submission.

Use an Admin App Store Connect team API key for managed signing. The previous
App Manager release key can submit builds but Apple rejects its cloud-signing
requests. Update the key ID and private key together in the existing secrets;
the issuer and app ID remain unchanged:

- `APP_STORE_CONNECT_APP_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY` (PEM or base64-encoded PEM)

Each upload receives an increasing UTC build number in `YYMM.DDHH.MMSS` form
(with leading zeroes removed). Retries therefore do not reuse a previously
uploaded build number. Processing selects the exact app, platform, public
version, and build number, and rejects failed or internal-only builds before
submission. Processing has a 45-minute deadline with live progress output.

By default releases are submitted to App Review and publish after approval.
`release_mode: manual` preserves manual publication. To validate signing and
upload without submitting, run the individual iOS/macOS workflow with
`submit_for_review: false`. This still uploads a build and waits for Apple to
process it, but does not change the App Store version or publish a GitHub release.

Build logs and Xcode result bundles are retained in GitHub for seven days. API
key files stay outside artifacts and are removed after upload.

## Migration from Xcode Cloud

The six old PR, TestFlight, and release workflows were disabled in App Store
Connect during migration. Their definitions and history remain available for
reference; keep them disabled to avoid duplicate builds. The old
`XCODE_CLOUD_IOS_WORKFLOW_ID` and `XCODE_CLOUD_MACOS_WORKFLOW_ID` secrets are no
longer used. Apple processing and App Review remain required after upload;
Xcode Cloud build capacity is no longer involved.
