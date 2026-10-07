# Builds and releases

There are four GitHub Actions workflows:

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| PR Checks & Preview | Pull requests | Analyze, test, compile all six platforms, publish artifacts and a Firebase web preview. |
| Beta Builds | Push to `main`, or manual | Android APK plus iOS/macOS TestFlight builds. |
| Deploy Web | Push to `main`, or manual | Build once and deploy to both `app.openwearables.com` and the existing Firebase site. |
| Release App | Manual | Release all platforms or select Android, iOS, macOS, or both Apple platforms. |

Copilot review/agent workflows are GitHub-managed and independent of app builds.
Old workflow runs remain in Actions history; there are no duplicate Firebase or
platform-specific release workflow files.

GitHub Actions builds iOS and macOS on standard `macos-15` runners with Xcode
26.2 and the Flutter version pinned in `.flutter_version`. Android, Linux,
Windows, and web continue using their existing GitHub runners.

## Pull requests

**PR Checks & Preview** compiles both Apple platforms without signing credentials.
These artifacts validate compilation; the unsigned iOS app cannot be installed
on a physical iPhone. Fork PRs do not receive Apple secrets or deploy previews.
Firebase previews reuse the web build artifact instead of rebuilding the app.

## TestFlight

**Beta Builds** archives both Apple platforms on each push to `main`, then submits
for Beta App Review when required and assigns the builds to the existing
**Internal Testing** and **External Testing** groups. This preserves the old
Xcode Cloud main-branch distribution settings, including automatic notification
when Apple makes an external build available. It does not submit a public App
Store release.

The workflow can also be run manually against a chosen ref. Manual runs default
to upload-only validation; enable `distribute` to send the build to those groups.

## App Store releases

Use **Release App**, with `platforms` set to `all`, `android`, `ios`, `macos`, or
`app_store` (both Apple platforms). The workflow keeps the existing
immutable version tag and release-note validation. Build scripts come from the
workflow revision, while app source comes from the release tag, so a CI fix can
release an existing tag without changing its contents.

The GitHub Mac archives the app, then Xcode signs and uploads it directly to App
Store Connect. Automatic signing uses the configured API key and Apple's managed
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
upload without submitting, select `ios`, `macos`, or `app_store` with
`submit_for_review: false`. This still uploads a build and waits for Apple to
process it, but does not change the App Store version or publish a GitHub release.

Set `validate_only: true` to check the selected source version and platform
selection without tagging, building, or uploading. Android releases retain the
`internal`/`production` track choice. GitHub release publication and the optional
version-bump PR wait for every selected platform to succeed; internal and Apple
upload-only runs do not publish a release. The version-bump PR targets `main`
unless `version_bump_base_ref` specifies another branch.

Build logs and Xcode result bundles are retained in GitHub for seven days. API
key files stay outside artifacts and are removed after upload.

## Migration from Xcode Cloud

The six old PR, TestFlight, and release workflows were disabled in App Store
Connect during migration. Their definitions and history remain available for
reference; keep them disabled to avoid duplicate builds. The old
`XCODE_CLOUD_IOS_WORKFLOW_ID` and `XCODE_CLOUD_MACOS_WORKFLOW_ID` secrets are no
longer used. Apple processing and App Review remain required after upload;
Xcode Cloud build capacity is no longer involved.
