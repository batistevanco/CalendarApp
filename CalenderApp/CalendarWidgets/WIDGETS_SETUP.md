# Widgets & Live Activities — Xcode setup

The widget/Live-Activity **code is written and compiles**, but a widget needs its
own *extension target* plus an *App Group*, which must be created in Xcode (these
are capability/target operations, not source changes). Adding a target by
hand-editing `project.pbxproj` risks corrupting the project, so do it in the UI —
it takes ~3 minutes.

## 1. Create the Widget Extension target
1. **File ▸ New ▸ Target… ▸ Widget Extension**.
2. Product Name: **CalendarWidgets**. ✅ Check **Include Live Activity**. Finish.
3. When asked to activate the new scheme, choose **Activate**.

## 2. Use the provided sources
Xcode generates template files in a new `CalendarWidgets/` group. Replace them
with the files already in this folder:
- Delete the auto-generated `CalendarWidgets.swift` / `*Bundle.swift` /
  `*LiveActivity.swift` templates (so there is only **one** `@main`).
- Add these files to the **CalendarWidgets** target:
  - `CalendarWidgetBundle.swift`
  - `EventLiveActivity.swift`
- Add the shared file to **both** targets:
  - `CalenderApp/WidgetShared/WidgetShared.swift` → select it, and in the File
    Inspector ▸ **Target Membership**, check **CalenderApp** *and* **CalendarWidgets**.

## 3. App Group (shared storage)
The app publishes an event snapshot the widget reads. Add the same App Group to
both targets:
1. Select the project ▸ **CalenderApp** target ▸ **Signing & Capabilities** ▸
   **+ Capability ▸ App Groups**. Add **`group.be.vancoilliestudio.CalenderApp`**.
2. Repeat for the **CalendarWidgets** target (same group id).

If you use a different id, update `AppGroup.identifier` in `WidgetShared.swift`.

## 4. Live Activities
- The app's `Info.plist` key `NSSupportsLiveActivities = YES` is already set (via
  build setting), so no action needed there.
- The extension's `NSSupportsLiveActivities` is added automatically because you
  checked "Include Live Activity" in step 1.

## 5. Build & run
Build the app once (so it writes a snapshot on launch/foreground), then add the
**Up Next** or **Today** widget from the Home/Lock Screen gallery. The Live
Activity appears automatically for the current/next event.

---

### What each file does
- **WidgetShared.swift** — `WidgetEvent`, the App-Group snapshot store, and the
  `EventActivityAttributes` for the Live Activity. Shared by both targets.
- **CalendarWidgetBundle.swift** — the `@main` bundle: **Up Next** (small +
  Lock Screen) and **Today** (medium/large schedule) widgets, driven by a
  timeline provider that reads the snapshot.
- **EventLiveActivity.swift** — the Lock Screen banner and Dynamic Island
  (compact/minimal/expanded) countdown UI.

The app side is already wired: `WidgetBridge.publish(...)` writes the snapshot and
reloads timelines, and `LiveActivityController` starts/updates the activity — both
called from `AppRootView` on launch and every foreground.
