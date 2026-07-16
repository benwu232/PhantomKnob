# User Guide: Welcome Page & Operations Quick Reference

We are adding a new welcome/introduction page as the first step of the User Guide, and a dedicated Operations & Shortcuts Quick Reference page as the final step. We are also adding an entry in the StatusBar menu to open the User Guide directly to the shortcuts page.

## Proposed Changes

### 1. User Guide View Model & Navigation

#### `UserGuideViewModel.swift`
- Add a new published property `currentStep` with default value of `1`.
- Update the step range from `1 ... 3` to `1 ... 5`:
  - **Step 1**: Welcome & Introduction
  - **Step 2**: Detect & Rotate (original Step 1)
  - **Step 3**: Advanced Knobs (original Step 2)
  - **Step 4**: Go Global (original Step 3)
  - **Step 5**: Operations & Shortcuts Quick Reference
- Expose a method to directly navigate to a specific step.
- Update `isStep2Unlocked` to check if original Step 1 has been completed (if needed).
- Handle the completion action on Step 5 (exit guide, update defaults).

### 2. User Guide UI Layout

#### `UserGuideView.swift`
- Update step rendering:
  - Add `welcomeView` for Step 1.
  - Render existing steps shifted by 1 (e.g., original Step 1 is now Step 2, original Step 2 is now Step 3, original Step 3 is now Step 4).
  - Add `shortcutsView` for Step 5.
- Update header titles and subtitles to support 5 steps.
- Update footer navigation:
  - Show "Previous" button for steps 2 to 5.
  - Show "Next" button for steps 1 to 4.
  - Enable Next button on Step 2 (originally Step 1) only after touchpad detection is successful.
  - Show "Exit" button on Step 5.
- Sub-components:
  - **Step 1 (Welcome)**: Centered PhantomKnob logo, title "Welcome to PhantomKnob", description text (referencing About description), and an action button "Start Onboarding Guide" (navigates to Step 2).
  - **Step 5 (Shortcuts & Operations)**: A clean grid or list categorized into:
    - **Status Bar Icon Operations**: Click (toggle mode), Double click (toggle panel), Right click (open menu).
    - **Keyboard Shortcuts**: Global control toggle shortcut (`⌘ ⌥ K`), Temporary bypass gesture (hold `Option` key).
    - **Auxiliary Keys During Rotation**:
      - `C` key (placed at the top): Press during rotation to open the Customizer panel.
      - `1` key: Reset rotation speed to 1.0x of base speed setting.
      - `2 - 9` keys: Set rotation speed multiplier to 2.0x ~ 9.0x of base speed setting.
      - `↑` / `↓` arrow keys: Increase/decrease rotation speed multiplier by 1.0x.
      - `←` / `→` arrow keys: Increase/decrease rotation speed multiplier by 0.1x.

### 3. Window Controller Deep Linking

#### `UserGuideWindowController.swift`
- Add an optional step parameter: `func show(step: Int? = nil)`.
- Pass this step to the hosted `UserGuideView` via the shared ViewModel or initializing a ViewModel with that initial step.
- Ensure the window is brought to front and gains key status correctly.

### 4. Status Bar Menu Entry

#### `StatusBarController.swift`
- Add a new menu item below "User Guide..." (使用引导...):
  - Title: "Shortcuts & Operations..." / "快捷键与操作速查..."
  - Selector/Action: `openShortcutsGuide`
- Implement `openShortcutsGuide` to call `UserGuideWindowController.shared.show(step: 5)`.

### 5. Localization Strings

#### `Localizable.xcstrings`
Add strings for:
- Welcome title & intro description.
- Step 5 titles, headers, descriptions, and operations lists (in English and Chinese).
- Status Bar menu item title.

## Verification Plan

### Automated Verification
- Run tests in `UserGuideViewModelTests.swift` to verify the step range updates and transition limits.
- Add test assertions to confirm navigating to step 5 updates `currentStep` correctly.

### Manual Verification
1. Launch the app and select "User Guide..." from the status bar menu. Verify the 5-step navigation, starting from the new Welcome page.
2. Complete Step 2 (practice dial) and verify the Next button unlocks.
3. Check the Step 5 page layout, confirming all shortcuts and status bar gestures are listed correctly, with the `C` key at the top of the auxiliary keys group.
4. Close the User Guide, click the status bar icon, and click the new menu item "快捷键与操作速查...".
5. Verify the User Guide opens directly to Step 5 (Shortcuts page).
