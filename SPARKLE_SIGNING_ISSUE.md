# Sparkle Auto-Update System: EdDSA Signing Issue in GitHub Actions

## Problem Summary

We have successfully implemented a Sparkle auto-update system for Microverse (a macOS system monitoring app) but are stuck on the final step: generating a properly signed appcast.xml in GitHub Actions CI. The `generate_appcast` tool consistently hangs in the CI environment, and we need expert guidance on EdDSA signing implementation.

## Current Architecture

### EdDSA Key Pair
- **Public Key**: `j6LhwdLf+L0uIllLkfIVFxNLHrg9f3lLUs/5uz5PF7w=` (configured in Info.plist)
- **Private Key**: Stored as `SPARKLE_PRIVATE_KEY` in GitHub Actions secrets
- **Generated with**: Sparkle's `generate_keys` tool

### Working Components ✅
1. **Sparkle Framework Integration**: Sparkle 2.7.1 properly integrated with SwiftUI
2. **GitHub Actions Workflow**: Builds releases, creates DMG/ZIP artifacts
3. **Keychain Setup**: Private key imported to GitHub Actions keychain
4. **GitHub Pages**: Ready to host appcast.xml at `https://microverse.ashwch.com/appcast.xml`
5. **App Configuration**: Info.plist properly configured with Sparkle settings

### The Problem ❌
The `generate_appcast` tool hangs indefinitely in GitHub Actions, preventing appcast generation.

## Detailed Problem Analysis

### Issue: `generate_appcast` Tool Hangs in CI

**Behavior**: The tool starts execution but hangs indefinitely without producing output or error messages.

**Environment**: GitHub Actions macOS runner (macos-latest)

**Debugging Steps Taken**:

#### 1. Initial Hanging (10+ minutes)
```bash
./sparkle-tools/generate_appcast releases/
# Process hangs indefinitely, never completes
```

#### 2. Added Timeout Detection
```bash
# Added 60-second timeout with background execution
./sparkle-tools/generate_appcast releases/ > appcast_output.log 2>&1 &
PID=$!
# Process consistently times out after 60 seconds with no output
```

#### 3. Parameter Variations Tested
```bash
# All of these hang:
./sparkle-tools/generate_appcast releases/
./sparkle-tools/generate_appcast releases/ --verbose
./sparkle-tools/generate_appcast releases/ --keychain-password ""
```

#### 4. Environment Analysis
- **Tool Permissions**: `rwxr-xr-x` (executable)
- **Keychain Access**: Login keychain accessible
- **File Structure**: ZIP file present in releases/ directory
- **Help Command**: `./sparkle-tools/generate_appcast --help` works fine

### Key Findings

1. **Tool Execution**: The process starts (gets PID) but never writes to output
2. **No Error Messages**: No stderr/stdout output captured
3. **Consistent Behavior**: Hangs regardless of parameters or keychain settings
4. **Interactive vs CI**: Strong indication of keychain/permission dialog blocking

## Current Implementation Code

### GitHub Actions Workflow (Relevant Section)
```yaml
- name: Setup Sparkle Signing
  if: steps.check_proceed.outputs.should_proceed == 'true'
  run: |
    echo "Setting up Sparkle signing..."
    
    # Add the EdDSA private key to keychain as a generic password
    security add-generic-password \
      -a "ed25519" \
      -s "https://sparkle-project.org" \
      -D "private key" \
      -w "${{ secrets.SPARKLE_PRIVATE_KEY }}" \
      ~/Library/Keychains/login.keychain-db
    
    echo "Private key imported successfully"

- name: Generate Signed Appcast
  if: steps.check_proceed.outputs.should_proceed == 'true'
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    echo "Generating signed appcast with Sparkle..."
    
    # Create directory for release assets
    mkdir -p releases
    
    # Download the ZIP file that was just uploaded
    ZIP_URL=$(gh api repos/${{ github.repository }}/releases/tags/${{ steps.version.outputs.new_tag }} \
      --jq '.assets[] | select(.name | endswith(".zip")) | .browser_download_url')
    
    curl -L -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
         -o "releases/${PRODUCT_NAME}-v${{ steps.version.outputs.new_version }}.zip" \
         "$ZIP_URL"
    
    # This is where it hangs:
    ./sparkle-tools/generate_appcast releases/ > appcast_output.log 2>&1 &
    PID=$!
    
    # Wait for up to 60 seconds (consistently times out)
    for i in {1..60}; do
      if ! kill -0 $PID 2>/dev/null; then
        echo "Process completed after $i seconds"
        break
      fi
      if [ $i -eq 60 ]; then
        echo "❌ Process still running after 60 seconds, killing it"
        kill $PID 2>/dev/null || true
        exit 1
      fi
      sleep 1
    done
```

### Info.plist Configuration
```xml
<!-- Sparkle Auto-Update Configuration -->
<key>SUFeedURL</key>
<string>https://microverse.ashwch.com/appcast.xml</string>
<key>SUAutomaticallyUpdate</key>
<false/>
<key>SUEnableAutomaticChecks</key>
<false/>
<key>SUShowReleaseNotes</key>
<true/>
<key>SUAllowsAutomaticUpdates</key>
<false/>
<!-- CRITICAL: Enable Installer XPC service for sandboxed apps -->
<key>SUEnableInstallerLauncherService</key>
<true/>
<!-- EdDSA public key for signature verification -->
<key>SUPublicEDKey</key>
<string>j6LhwdLf+L0uIllLkfIVFxNLHrg9f3lLUs/5uz5PF7w=</string>
```

### SwiftUI Integration
```swift
@MainActor
class SecureUpdateService: NSObject, ObservableObject {
    @Published var updateAvailable = false
    @Published var isCheckingForUpdates = false
    @Published var currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    @Published var latestVersion: String?
    @Published var lastUpdateCheck: Date?
    
    private let logger = Logger(subsystem: "com.microverse.app", category: "SecureUpdateService")
    private var updater: SPUUpdater!
    
    static let shared = SecureUpdateService()
    
    override init() {
        super.init()
        
        let userDriver = SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil)
        self.updater = SPUUpdater(hostBundle: Bundle.main, applicationBundle: Bundle.main, userDriver: userDriver, delegate: self)
        
        do {
            try updater.start()
        } catch {
            logger.error("Sparkle failed to start: \(error)")
            return
        }
        
        setupUpdater()
        loadLastUpdateCheck()
    }
    
    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        
        isCheckingForUpdates = true
        lastUpdateCheck = Date()
        saveLastUpdateCheck()
        
        updater.checkForUpdateInformation()
    }
}

extension SecureUpdateService: SPUUpdaterDelegate {
    // Delegate methods implemented...
}
```

## Error Logs & Traces

### Latest Workflow Run Log
```
build-and-release	Generate Signed Appcast	2025-08-14T09:17:14.9896000Z Running generate_appcast in background...
build-and-release	Generate Signed Appcast	2025-08-14T09:17:14.9896280Z Started generate_appcast with PID: 5045
build-and-release	Generate Signed Appcast	2025-08-14T09:18:21.2923160Z ❌ Process still running after 60 seconds, killing it
build-and-release	Generate Signed Appcast	2025-08-14T09:18:21.2929330Z Process output:
build-and-release	Generate Signed Appcast	2025-08-14T09:18:21.2990640Z /Users/runner/work/_temp/6c32ff07-afee-45b6-a966-cfbe04e06535.sh: line 50:  5045 Terminated: 15          ./sparkle-tools/generate_appcast releases/ > appcast_output.log 2>&1
build-and-release	Generate Signed Appcast	2025-08-14T09:18:21.3014500Z ##[error]Process completed with exit code 1.
```

### Keychain Status in CI
```
build-and-release	Generate Signed Appcast	2025-08-14T09:13:29.5607040Z Keychain status:
build-and-release	Generate Signed Appcast	2025-08-14T09:13:29.5607250Z     "/Users/runner/Library/Keychains/login.keychain-db"
build-and-release	Generate Signed Appcast	2025-08-14T09:13:29.5607370Z     "/Library/Keychains/System.keychain"
```

### Tool Help Output (This Works)
```
OVERVIEW: Generate appcast from a directory of Sparkle update archives.

Appcast files and deltas will be written to the archives directory.

If an appcast file is already present in the archives directory, that file will
be re-used and updated with new entries.
Otherwise, a new appcast file will be generated and written.

Old updates are automatically removed from the generated appcast feed and their
update files are moved to old_updates/
If --auto-prune-update-files is passed, old update files in this directory are
deleted after 2 weeks.
You may want to exclude files from this directory from being uploaded.

Use the --versions option if you need to insert an update that is older than
the latest update in your feed, or
if you need to insert only a specific new version with certain parameters.

USAGE: generate_appcast <archives-path> [--versions <versions>] [--maximum-versions <maximum-versions>] [--maximum-deltas <maximum-deltas>] [--auto-prune-update-files] [--embed-release-notes] [--channel <channel>] [--link <link>] [--full-release-notes-url <full-release-notes-url>] [--release-notes-url-prefix <release-notes-url-prefix>] [--download-url-prefix <download-url-prefix>] [--keychain-password <keychain-password>] [--account <account>] [--private-key-file <private-key-file>]

ARGUMENTS:
  <archives-path>         Path to directory containing update archives

OPTIONS:
  --keychain-password <keychain-password>
                          Keychain password to use for accessing signing private key from the default keychain. If no keychain item is found but a private key file exists, this password will be used for reading the private key file. 
  --account <account>     Account name to use for accessing signing private key from the default keychain. The default account name is the first 8 characters of the public key hash. 
  --private-key-file <private-key-file>
                          Path to private key file. The private key from the default keychain will be preferred over a private key file. 
  -h, --help              Show help information.
```

## Questions for macOS Expert

### Primary Questions:

1. **Why does `generate_appcast` hang in GitHub Actions CI?**
   - Is this a known issue with Sparkle tools in non-interactive environments?
   - Are there specific flags or environment variables needed for CI execution?

2. **EdDSA Signature Generation**: 
   - How can we manually generate the correct EdDSA signature for the appcast?
   - What's the exact algorithm/process Sparkle uses for `sparkle:edSignature`?

3. **Alternative Approaches**:
   - Can we use `sign_update` tool directly instead of `generate_appcast`?
   - Is there a way to make the keychain access non-interactive?
   - Should we use a different approach for CI environments?

### Technical Specifics:

4. **Keychain Access**:
   ```bash
   # Is this the correct way to import the key?
   security add-generic-password \
     -a "ed25519" \
     -s "https://sparkle-project.org" \
     -D "private key" \
     -w "$PRIVATE_KEY" \
     ~/Library/Keychains/login.keychain-db
   ```

5. **Manual Signature Process**:
   - What data exactly needs to be signed for `sparkle:edSignature`?
   - Is it just the file content, or does it include metadata like filename/size?
   - What's the exact OpenSSL command equivalent?

## Required Appcast Format

We need to generate this structure with proper EdDSA signature:
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
   <channel>
      <title>Microverse Changelog</title>
      <link>https://microverse.ashwch.com/appcast.xml</link>
      <description>Most recent changes with links to updates.</description>
      <language>en</language>
         <item>
            <title>Version X.X.X</title>
            <description><![CDATA[Release notes...]]></description>
            <pubDate>Date</pubDate>
            <enclosure url="https://github.com/ashwch/microverse/releases/download/vX.X.X/Microverse-vX.X.X.zip"
                      sparkle:version="X.X.X"
                      sparkle:shortVersionString="X.X.X"
                      length="FILE_SIZE_BYTES"
                      type="application/octet-stream"
                      sparkle:edSignature="SIGNATURE_NEEDED_HERE" />
            <sparkle:minimumSystemVersion>11.0</sparkle:minimumSystemVersion>
        </item>
   </channel>
</rss>
```

## Repository Information

- **Repository**: https://github.com/ashwch/microverse
- **Language**: Swift (macOS app using SwiftUI)
- **Sparkle Version**: 2.7.1
- **Target**: macOS 11.0+
- **CI Environment**: GitHub Actions macos-latest

## Files Attached/Referenced

1. **Complete workflow**: `.github/workflows/release.yml`
2. **Update service**: `Sources/Microverse/SecureUpdateService.swift` 
3. **App entitlements**: `Microverse.entitlements`
4. **Package configuration**: `Package.swift`

The system is 95% complete - we just need the final piece: reliable appcast generation with EdDSA signatures in the CI environment.