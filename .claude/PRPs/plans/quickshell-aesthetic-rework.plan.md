# Plan: Quickshell Aesthetic Rework

## Summary
Reduce redundancy in the Quickshell bar by merging three separate system-metric widgets (Cpu, Ram, Disk) into one compact SysMetrics widget, remove the Cachy terminal shortcut (redundant with launcher), redesign the Clock for more visual impact, and add a left-border accent to notifications. The result is a cleaner, taller-feeling bar with less visual noise and a more polished look comparable to top r/unixporn posts.

## User Story
As a user, I want a cleaner, less redundant bar that looks better on a 56px wide sidebar, so that it feels more intentional and aesthetically pleasing without losing functionality.

## Problem → Solution
Three 44px widgets stacked (Cpu+Ram+Disk = ~132px + spacing) that all follow the same icon+% pattern → one 90px SysMetrics widget with three compact rows. Cachy button opens a terminal that the launcher already handles → removed. Clock is two plain stacked numbers → styled with a vertical accent line for visual weight.

## Metadata
- **Complexity**: Medium
- **Source PRD**: N/A
- **PRD Phase**: N/A
- **Estimated Files**: 5 modified, 1 created, 4 deleted
- **Bar width**: 56px (implicitWidth in Bar.qml)

---

## UX Design

### Before (top section of bar)
```
┌──────────────────────┐
│  [Cachy icon]        │  44px — terminal launcher (redundant)
│  HH                  │  52px — Clock
│  MM (accent)         │
│  󰻠  42%              │  44px — Cpu
│  󰍛  61%              │  44px — Ram
│  󰋊  18%              │  44px — Disk
│  ──────              │  separator
│  [Workspaces...]     │
└──────────────────────┘
Top section total: ~280px
```

### After
```
┌──────────────────────┐
│  │ HH               │  52px — Clock with left accent bar
│  │ MM               │
│  󰻠 CPU 42%          │  90px — SysMetrics (3 compact rows)
│  󰍛 RAM 61%          │
│  󰋊 DSK 18%          │
│  ──────              │  separator
│  [Workspaces...]     │
└──────────────────────┘
Top section total: ~162px (saves ~118px)
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Cachy button | Opens terminal | Removed | Use launcher (Super+Space) |
| CPU click | Opens htop | Preserved in SysMetrics | Click anywhere on widget = htop |
| Clock click | Toggles HH:MM ↔ DD/MM | Preserved | Same behaviour |
| SysMetrics hover | N/A (3 separate tooltips) | Single combined tooltip | "CPU 42%  RAM 61%  Disk 18%" |
| Notification | Plain left edge | Urgency-colored left border | low=color4, normal=color8, critical=color1 |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `Bar/widgets/Cpu.qml` | all | Pattern to port into SysMetrics rows |
| P0 | `Bar/widgets/Clock.qml` | all | File being updated |
| P0 | `Bar/Bar.qml` | all | Widget instantiation to change |
| P0 | `Bar/widgets/qmldir` | all | Must register/unregister exports |
| P1 | `Bar/widgets/Ram.qml` | all | Logic to merge into SysMetrics |
| P1 | `Bar/widgets/Disk.qml` | all | Logic to merge into SysMetrics |
| P1 | `Notifications/NotifItem.qml` | all | File receiving urgency border |
| P2 | `Theme/Colors.qml` | all | Color constants |

---

## Patterns to Mirror

### WIDGET_STRUCTURE
```qml
// SOURCE: Bar/widgets/Cpu.qml:5-8
Item {
    id: root
    property var barScreen
    width: 44; height: 44
}
```

### TOOLTIP_PATTERN
```qml
// SOURCE: Bar/widgets/Cpu.qml:26-31
MouseArea {
    id: ma; anchors.fill: parent; hoverEnabled: true
    onClicked: htopProc.running = true
    onEntered: TooltipState.show(
        "CPU  " + Math.round(root.cpuPercent) + "%  ·  click for htop",
        mapToGlobal(0, height / 2).y, root.barScreen)
    onExited: TooltipState.hide()
}
```

### FILE_READ_CPU
```qml
// SOURCE: Bar/widgets/Cpu.qml:34-51
readonly property FileView statFile: FileView { path: "/proc/stat"; watchChanges: false }
Timer {
    interval: 2000; running: true; repeat: true
    onTriggered: {
        root.statFile.reload()
        const text = root.statFile.text()
        if (!text) return
        const parts = text.split("\n")[0].split(/\s+/).slice(1).map(Number)
        const idle  = parts[3] + parts[4]
        const total = parts.reduce((a, b) => a + b, 0)
        if (root._prev) {
            const dT = total - root._prev.total
            const dI = idle  - root._prev.idle
            root.cpuPercent = dT > 0 ? (1 - dI / dT) * 100 : 0
        }
        root._prev = { total, idle }
    }
}
```

### CLOCK_PATTERN
```qml
// SOURCE: Bar/widgets/Clock.qml:4-34
Item {
    id: root
    property var barScreen
    width: 44; height: 52
    property bool showDate: false
    property date currentTime: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.currentTime = new Date() }
    // Column with HH + MM (color4)
    // MouseArea with TooltipState showing full date
}
```

### BAR_TOP_COLUMN
```qml
// SOURCE: Bar/Bar.qml:29-37
Column {
    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
    spacing: 4
    Cachy {}
    Clock { barScreen: root.modelData }
    Cpu { barScreen: root.modelData }
    Ram { barScreen: root.modelData }
    Disk { barScreen: root.modelData }
}
```

### PROCESS_PATTERN
```qml
// SOURCE: Bar/widgets/Cpu.qml:33
Process { id: htopProc; command: ["sh", "-c", "ghostty -e htop"] }
```

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `Bar/widgets/SysMetrics.qml` | CREATE | Merged Cpu+Ram+Disk widget |
| `Bar/widgets/Cpu.qml` | DELETE | Replaced by SysMetrics |
| `Bar/widgets/Ram.qml` | DELETE | Replaced by SysMetrics |
| `Bar/widgets/Disk.qml` | DELETE | Replaced by SysMetrics |
| `Bar/widgets/Cachy.qml` | DELETE | Redundant with launcher |
| `Bar/widgets/Clock.qml` | UPDATE | Add vertical accent bar |
| `Bar/widgets/qmldir` | UPDATE | Remove old exports, add SysMetrics |
| `Bar/Bar.qml` | UPDATE | Replace Cachy+Cpu+Ram+Disk with SysMetrics |
| `Notifications/NotifItem.qml` | UPDATE | Add urgency-colored left border |

## NOT Building
- Removing AudioGroup/BrightnessGroup from bar (user wants quick access)
- Redesigning dashboard layout (separate concern)
- Removing Mpris from bar (different collapse-to-icon UX)
- Changing bar width from 56px

---

## Step-by-Step Tasks

### Task 1: Create SysMetrics.qml
- **ACTION**: Create `Bar/widgets/SysMetrics.qml`
- **IMPLEMENT**: Three compact rows in a Column (total height 90px). Each row = icon (Nerd Font, 12px, load-colored) + "LBL NN%" text (9px). CPU reads `/proc/stat` every 2s (same diff logic as Cpu.qml). RAM reads `/proc/meminfo` every 3s (MemTotal - MemAvailable). Disk runs `["df","--output=pcent","/"]` via Process every 10s. Single MouseArea: hover = combined tooltip, click = htop.
  ```
  Per-row height: 28px
  Row layout: icon (left+4) + gap 4 + "CPU 42%" text
  Column spacing: 3, total: 28*3 + 3*2 = 90
  ```
  Icons: CPU=`󰻠`, RAM=`󰍛`, Disk=`󰋊`
  Color logic: >80%=color1 (red), >50%=color3 (yellow), else=color2 (green)
- **MIRROR**: FILE_READ_CPU, TOOLTIP_PATTERN, WIDGET_STRUCTURE, PROCESS_PATTERN
- **IMPORTS**: `import QtQuick`, `import Quickshell.Io`, `import "../../Theme"`
- **GOTCHA**: `df --output=pcent /` output has a header line — split `\n`, take index 1, then `.trim().replace("%","")`. RAM from /proc/meminfo: find lines matching `/^MemTotal:/` and `/^MemAvailable:/`, parse kB values, percent = `(1 - avail/total) * 100`.
- **VALIDATE**: Three rows show with icons and updating percentages. Hover tooltip shows all three. Click opens htop.

### Task 2: Update Clock.qml — add vertical accent bar
- **ACTION**: Edit `Bar/widgets/Clock.qml` to add a 2×32px accent Rectangle to the left of the time column
- **IMPLEMENT**: Replace the `Column { anchors.centerIn: parent }` with a `Row { anchors.centerIn: parent; spacing: 5 }` containing the accent Rectangle first, then the existing Column:
  ```qml
  Row {
      anchors.centerIn: parent
      spacing: 5
      Rectangle {
          width: 2; height: 32; radius: 1
          color: Colors.color4
          anchors.verticalCenter: parent.verticalCenter
      }
      Column {
          spacing: 0
          Text { /* HH or DD — same as before */ }
          Text { /* MM or MM — same as before */ }
      }
  }
  ```
- **MIRROR**: CLOCK_PATTERN
- **GOTCHA**: Root Item `height` stays at 52. Do not change `width: 44`. The Row will center itself within the 44×52 Item.
- **VALIDATE**: Clock renders with a short vertical bar left of the digits. Toggle to date still works. Tooltip still shows full date.

### Task 3: Update qmldir
- **ACTION**: Edit `Bar/widgets/qmldir`
- **IMPLEMENT**: Remove lines for `Cachy 1.0 Cachy.qml`, `Cpu 1.0 Cpu.qml`, `Ram 1.0 Ram.qml`, `Disk 1.0 Disk.qml`. Add `SysMetrics 1.0 SysMetrics.qml`.
- **MIRROR**: Existing qmldir line format: `Name 1.0 Name.qml`
- **VALIDATE**: qmldir has SysMetrics, Clock, AudioGroup, BrightnessGroup, Battery, Mpris, Workspaces, ActiveWindow, NetworkSpeed, PowerButton, Privacy. No Cachy/Cpu/Ram/Disk.

### Task 4: Update Bar.qml
- **ACTION**: In the top Column in Bar.qml, replace `Cachy {}` and `Cpu/Ram/Disk { barScreen: root.modelData }` with `SysMetrics { barScreen: root.modelData }`
- **MIRROR**: BAR_TOP_COLUMN
- **GOTCHA**: Keep `Clock { barScreen: root.modelData }` — only removing Cachy and three sys widgets, replacing with one SysMetrics.
- **VALIDATE**: Top column reads: Clock, SysMetrics. No Cachy, Cpu, Ram, Disk.

### Task 5: Add urgency border to NotifItem.qml
- **ACTION**: Read NotifItem.qml in full, then add a 3px left-border Rectangle inside the root
- **IMPLEMENT**: Add as the first child of the root Rectangle (so it sits on top of the background, below notification content):
  ```qml
  Rectangle {
      anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
      width: 3; radius: 1
      color: modelData.urgency === 2 ? Colors.color1
           : modelData.urgency === 0 ? Colors.color4
           : Colors.color8
      opacity: 0.9
  }
  ```
- **GOTCHA**: Verify the urgency property name — grep NotifItem.qml for `urgency` before writing. If it's a string (`"critical"`, `"normal"`, `"low"`) adjust comparisons accordingly. If it's on a nested object (e.g. `modelData.notification.urgency`), use the correct path.
- **VALIDATE**: A critical notification shows red left bar. A normal notification shows muted bar. The bar does not overflow the notification corners.

### Task 6: Delete retired files
- **ACTION**: Delete `Bar/widgets/Cachy.qml`, `Bar/widgets/Cpu.qml`, `Bar/widgets/Ram.qml`, `Bar/widgets/Disk.qml`
- **GOTCHA**: Confirm zero references remain first: `grep -r "Cachy\b\|<Cpu\b\|<Ram\b\|<Disk\b" configs/quickshell/`
- **VALIDATE**: Grep returns no matches.

---

## Validation Commands

### Static Analysis
```bash
# No broken widget references
grep -rn "Cachy\b\|\"Cpu\"\|\"Ram\"\|\"Disk\"" configs/quickshell/Bar/
```
EXPECT: Zero matches

```bash
# qmldir correct
cat configs/quickshell/Bar/widgets/qmldir
```
EXPECT: SysMetrics present, Cachy/Cpu/Ram/Disk absent

### Manual Validation
- [ ] Bar starts without errors
- [ ] Top section is visually shorter than before
- [ ] SysMetrics shows three rows with icons and percentages
- [ ] Hovering SysMetrics shows a combined tooltip
- [ ] Clicking SysMetrics opens htop in ghostty
- [ ] Clock shows vertical accent bar beside HH/MM
- [ ] Clock date toggle (click) still works
- [ ] Notification shows colored left border based on urgency

---

## Acceptance Criteria
- [ ] Cachy removed from bar
- [ ] Cpu, Ram, Disk replaced by single SysMetrics widget
- [ ] SysMetrics shows all three metrics with correct icons and colors
- [ ] Clock has vertical accent bar
- [ ] NotifItem has urgency-based left border
- [ ] qmldir updated (no dead exports)
- [ ] Old .qml files deleted
- [ ] No Quickshell startup errors

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| NotifItem urgency field name differs from `modelData.urgency` | Medium | Low | Read file fully in Task 5 before writing |
| df command output format varies | Low | Medium | Test with `--output=pcent` flag specifically |
| Row centering shifts Clock pixels visually | Low | Low | Keep root height: 52, Row auto-centers |
| qmldir missing entry causes "Type unavailable" | Low | High | Double-check after editing |

## Notes
- Bar width is 56px. All widgets use width: 44 (centered via Column's horizontalCenter anchor).
- SysMetrics height 90px vs old 132px+16px spacing = saves ~58px. Removing Cachy saves 44+4px = 48px. Total: ~106px saved in top section.
- The vertical accent on Clock echoes the sliding pill accent in Workspaces — consistent visual language.
- Do NOT re-add NetworkSpeed widget — it was added in the previous session and is in the middle column.
- Run `/prp-implement .claude/PRPs/plans/quickshell-aesthetic-rework.plan.md` to execute.
