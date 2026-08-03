# Status Bar Menu License Management Design

## Overview
Currently, when PhantomKnob is activated as Pro (`.licensed`), the status bar right-click menu only displays a disabled header `License: Pro` and provides no clickable menu item to open the License Window. Pro users have no clear way to view their bound account email or unbind their device from the status bar menu.

This spec details updating the status bar menu item logic to display "Upgrade to Pro..." ("升级到专业版...") for Free users and "Manage License..." ("许可管理...") for Pro users. Both menu items open the existing `LicenseWindowView`.

## User Interface & Behavior
- **Free Edition (`.free`)**:
  - Displays menu item `menu.upgradeToPro`: "🛒 升级到专业版..." ("🛒 Upgrade to Pro...")
  - Action: Opens `LicenseWindow` (showing feature comparison and activation entry).
- **Pro Edition (`.licensed`)**:
  - Displays menu item `menu.manageLicense`: "🔑 许可管理..." ("🔑 Manage License...")
  - Action: Opens `LicenseWindow` (showing active status, masked email, and the "Unbind Current Device" / "解绑当前设备" button).
- **Trialing (`.trialing(daysRemaining)`)**:
  - Remaining days < 3: Displays `menu.buyPro`: "🛒 购买 PhantomKnob Pro..." ("🛒 Buy PhantomKnob Pro...")
  - Remaining days >= 3: Displays `menu.upgradeToPro`: "🛒 升级到专业版..." ("🛒 Upgrade to Pro...")

## System Changes

### 1. `PhantomKnob/Service/StatusBarController.swift`
- Update `setupMenu()` switch statement for `LicenseManager.shared.currentState`:
  - Under `.licensed`, construct and append `manageItem` `NSMenuItem` targeting `#selector(openLicenseWindow)`.
  - Under `.free`, construct and append `buyItem` `NSMenuItem` targeting `#selector(openLicenseWindow)`.
  - Alias or rename `#selector(buyPro)` to `#selector(openLicenseWindow)`.

### 2. `PhantomKnob/Localizable.xcstrings`
- Add localized string entry `menu.manageLicense`:
  - Chinese: `🔑 许可管理...`
  - English: `🔑 Manage License...`

### 3. Automated Tests (`PhantomKnobTests/StatusBarControllerTests.swift`)
- Add unit tests verifying:
  - When license state is `.free`, menu contains `menu.upgradeToPro` item.
  - When license state is `.licensed`, menu contains `menu.manageLicense` item.

## Verification Plan
1. **Automated Tests**:
   - Run unit tests in `StatusBarControllerTests.swift`.
2. **Manual Verification**:
   - Toggle license state between Free and Pro using debug options or state mocking.
   - Verify status menu shows "升级到专业版..." in Free mode and "许可管理..." in Pro mode.
   - Click "许可管理..." in Pro mode and verify `LicenseWindow` displays bound email and unbind button.
