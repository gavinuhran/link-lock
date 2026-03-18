# Link Lock — Setup TODO

All Swift source files are written and on main. The Xcode project itself must be created manually (cannot be done from the CLI without extra tooling).

---

## Your Steps (manual, in order)

### 1. Create the Xcode Project
- Open Xcode → File → New → Project → iOS App
- Name: `LinkLock`
- Bundle ID: `com.<yourname>.LinkLock`
- Interface: SwiftUI
- Language: Swift
- Minimum deployment: iOS 16.0
- Check "Include Tests"
- Save into: `/Users/gavinuhran/programming/link-lock/`  
  (Xcode will create `LinkLock.xcodeproj` alongside the existing folders)

### 2. Add Source Files to the App Target
In Xcode's Project Navigator, right-click the `LinkLock` group → Add Files:
- `LinkLock/LinkLockApp.swift`
- `LinkLock/Models/` — `Session.swift`, `PolicyDecision.swift`, `HistoryEntry.swift`
- `LinkLock/Engine/` — `NavigationPolicyEngine.swift`, `SessionManager.swift`
- `LinkLock/Extensions/` — `URL+Canonical.swift`
- `LinkLock/Persistence/` — `EventLogger.swift`, `HistoryStore.swift`
- `LinkLock/Views/` — `WebView.swift`, `BrowserView.swift`, `HomeView.swift`, `BlockedNavigationOverlay.swift`

Ensure target membership = `LinkLock` (app target) for all of the above.

> Delete any auto-generated `ContentView.swift` or `Assets.xcassets` that Xcode created — they will conflict.

### 3. Add Test File to the Test Target
Add Files → `LinkLockTests/NavigationPolicyEngineTests.swift`  
Target membership = `LinkLockTests` (test target only, **not** the app target).

### 4. Add the Share Extension Target
- File → New → Target → Share Extension
- Name: `LinkLockShareExtension`
- Delete the auto-generated `ShareViewController.swift` Xcode creates
- Add Files → `LinkLockShareExtension/ShareViewController.swift`  
  Target membership = `LinkLockShareExtension` only

### 5. Configure the Share Extension Info.plist
Open `LinkLockShareExtension/Info.plist` and make two changes:

a) **Delete** the key: `NSExtensionMainStoryboard`

b) **Add** these keys:

```xml
<key>NSExtensionPrincipalClass</key>
<string>$(PRODUCT_MODULE_NAME).ShareViewController</string>

<key>NSExtensionActivationRule</key>
<string>SUBPREDICATE_COUNT(extensionItems[cd].attachments[cd],
{NSExtensionItemAttachmentsKey LIKE "public.url"}, 1) == 1</string>
```

### 6. Register the `linklock://` URL Scheme (main app Info.plist)
Open `LinkLock/Info.plist` and add:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>linklock</string></array>
    <key>CFBundleURLName</key>
    <string>com.<yourname>.LinkLock</string>
  </dict>
</array>
```

### 7. Assign Signing Teams
- Select the `LinkLock` project in the Navigator
- For both targets (`LinkLock` + `LinkLockShareExtension`):  
  Signing & Capabilities → Team → select your Apple ID / team

### 8. Build & Run
- `Cmd+B` to build. Fix any errors (likely just missing file/target membership).
- `Cmd+U` to run unit tests (should see 30 passing).
- `Cmd+R` to run on simulator or device.

---

## Once You're Done — I Will Handle

**A.** Add a `.gitignore` for Xcode (excludes `.xcodeproj/xcuserdata`, `DerivedData`, etc.) and commit it.

**B.** Write a `project.yml` for xcodegen so the Xcode project can be regenerated from the CLI in the future (no more manual target/file wiring).

**C.** First-build triage — if you hit compile errors, share them and I'll fix the source files.

**D.** Manual QA assist — walk through the 11 manual test cases from the plan and fix any policy edge cases that don't behave as expected.

**E.** Anything else that comes up.
