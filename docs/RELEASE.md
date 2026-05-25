# Release Checklist

Spotlite releases should be signed with a Developer ID Application certificate, notarized by Apple, stapled, zipped, and uploaded to GitHub Releases.

## One-Time Apple Setup

1. Install a valid `Developer ID Application` certificate in the login keychain.
2. Confirm the certificate is visible:

   ```sh
   security find-identity -v -p codesigning
   ```

3. Create an app-specific password for your Apple ID.
4. Store notarization credentials in the keychain:

   ```sh
   xcrun notarytool store-credentials spotlite-notary \
     --apple-id "APPLE_ID_EMAIL" \
     --team-id "TEAM_ID" \
     --password "APP_SPECIFIC_PASSWORD"
   ```

## Build a Signed Release ZIP

```sh
scripts/release_notarized_zip.sh 1.0
```

The script builds `build/Spotlite.app`, signs it with the first available `Developer ID Application` identity, submits it for notarization, staples the ticket, verifies Gatekeeper assessment, and writes:

```text
build/release/Spotlite-v1.0-macos.zip
```

If you have multiple Developer ID identities, set the exact one:

```sh
SPOTLITE_DEVELOPER_ID_IDENTITY="Developer ID Application: Name (TEAMID)" \
  scripts/release_notarized_zip.sh 1.0
```

## GitHub Release

Upload the final ZIP to the matching GitHub release. Homebrew casks should use the notarized ZIP URL and its SHA-256.
