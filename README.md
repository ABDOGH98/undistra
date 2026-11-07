<p align="center">
  <img src="Branding/undistra-icon-1024.png" width="160" alt="Undistra app icon">
</p>

<h1 align="center">Undistra</h1>

<p align="center">
  <strong>Focus on one thing.</strong><br>
  A macOS app that locks away distracting apps and websites while you work.
</p>

<p align="center">
  macOS 14+ · SwiftUI · No third-party dependencies
</p>

---

## Contents
- [Features](#features)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [How to use it](#how-to-use-it)
- [Silencing notifications](#silencing-notifications)
- [How it works](#how-it-works)
- [Project structure](#project-structure)
- [Where data is stored](#where-data-is-stored)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Design principles](#design-principles)
- [Brand](#brand)
- [Known limits and roadmap](#known-limits-and-roadmap)

---

## Features

| | |
|---|---|
| 🔒 **Blocks apps** | A blocked app closes as soon as it opens during a session. A window offers **Stay Focused**, or your passcode to open the app for 5–30 minutes. |
| 🌐 **Blocks websites** | YouTube, Instagram, Facebook and anything else you add won't load in **any** browser. The `www.` and mobile (`m.`) versions are blocked too. |
| 🔕 **Quiets notifications** | Blocked apps are closed, so they can't notify you. Undistra can also turn on **Do Not Disturb** through Shortcuts. |
| ⏱️ **Focus sessions** | Start a 25, 50 or 90 minute session (or any length), with a progress ring and countdown. |
| 📅 **Schedules** | Focus starts by itself, for example *Mon–Fri 9:00–12:00*. Overnight schedules like *22:00–07:00* work too. |
| 🎯 **Intentions** | Write what you'll work on. You'll see it during the session and when you try to open a blocked app. |
| 🔥 **Stats and streaks** | Time focused today, completed sessions, and how many days in a row you've focused. |
| 🛡️ **Hard to cheat** | Ending early needs your passcode. During a session you can't remove blocked items, turn off schedules, or quit the app. Three wrong passcodes lock you out for 60 seconds. |
| 📍 **Menu bar** | Start a session, see time left and your task, all from the menu bar. |

## Requirements
- macOS 14 Sonoma or later
- Xcode 16 or later (the project was made with Xcode 26)
- An admin account on the Mac (needed to block websites)

## Getting started

### Download
Get the latest **`Undistra-x.y.z.dmg`** from [Releases](https://github.com/ABDOGH98/undistra/releases/latest), open it, and drag Undistra into **Applications**.

> The app isn't notarized yet, so macOS warns you on first launch. Go to **System Settings → Privacy & Security → Open Anyway**, or run `xattr -dr com.apple.quarantine /Applications/Undistra.app`.

### Run from Xcode
1. Open `Undistra.xcodeproj`.
2. Choose the **Undistra** scheme and **My Mac**.
3. Press **⌘R**.

### Build from the terminal
```bash
xcodebuild -project Undistra.xcodeproj -scheme Undistra -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Undistra.app
```

### First launch
A short welcome guide walks you through setup:
1. **Pick your distractions.** Choose website categories (Social media, Video, News, Shopping) and apps from suggestions.
2. **Create a passcode.** Pick a long one: having to type it gives you a moment to ask *"do I really need this?"*
3. **Start a first 25-minute session**, or start later.

You can open the guide again anytime from **Settings → Show Welcome Guide Again**.

## How to use it

### Start a session
1. Go to **Focus** in the sidebar, or open the menu-bar icon.
2. Optional: type what you'll work on.
3. Pick a length and press **Start**. macOS asks for your password once, to block websites.

### When you open a blocked app
The app closes and the Undistra window appears:
- **Stay Focused** (or press Esc) closes the window.
- **I really need it…** asks for your passcode and opens the app for 5, 10, 15 or 30 minutes. After that, it closes again by itself.

### End a session early
On the Focus screen, click **End early…** and enter your passcode.

### Block List
- **Apps:** pick from apps that are open right now or common distractions, or click **Choose Another App…**
- **Websites:** turn on a whole category with one click, or type any address. Full links like `https://www.youtube.com/watch?v=…` are cleaned up to `youtube.com` automatically.
- During a session you can **add** items, but removing them waits until it ends.

### Schedules
Add one of the ready-made schedules or make your own. Each schedule shows **Active now** or when it starts next.

> **Tip:** turn on **Settings → Open Undistra at login**. Schedules only work while the app is running.

## Silencing notifications
Apple doesn't let apps mute other apps' notifications directly, so Undistra runs two shortcuts that you create once:

1. Open the **Shortcuts** app.
2. Create a shortcut named **`Undistra On`** with the action **Set Focus → Do Not Disturb → On**.
3. Create a shortcut named **`Undistra Off`** with **Set Focus → Do Not Disturb → Off**.
4. In Undistra, go to **Settings → Notifications**, turn on **Turn on Do Not Disturb during focus**, and press **Test On**.

You can use other shortcut names. Just type them in Settings.

## How it works

```
                       ┌──────────────────────────────┐
  Manual session ─────►│                              │──► AppBlocker ───► closes blocked apps
  Schedules ──────────►│  FocusStore.evaluate()       │──► WebsiteBlocker ► updates /etc/hosts
  Passcode unlocks ───►│  (runs every 5 seconds)      │──► FocusModeController ► runs Shortcuts
                       └──────────────────────────────┘
```

- **Deciding when focus is on:** `FocusStore` checks every 5 seconds whether a manual session or an enabled schedule is active, then starts or stops blocking when that changes.
- **App blocking:** `AppBlocker` listens for app launch and activation events from `NSWorkspace`. Blocked apps are asked to quit and force-quit after 3 seconds if they don't.
- **Website blocking:** `WebsiteBlocker` writes a marked section to `/etc/hosts` that points each blocked site to `0.0.0.0`. It uses macOS's standard admin prompt (`osascript … with administrator privileges`), then clears the DNS cache. Updates run one at a time, and only when the file would actually change.
- **Passcode:** only a **salted SHA-256 hash** is stored, in the macOS Keychain. The passcode itself is never saved.
- **Do Not Disturb:** runs your shortcuts with `/usr/bin/shortcuts run`.

### Why the App Sandbox is off
A sandboxed app can't close other apps or edit `/etc/hosts`, so the sandbox is turned off (`ENABLE_APP_SANDBOX = NO`). This means Undistra **can't be sold on the Mac App Store**. Distribute it as a **notarized app signed with a Developer ID** instead.

## Project structure

```
focus-app/
├── Undistra.xcodeproj
├── Undistra/
│   ├── App/
│   │   └── UndistraApp.swift        # App entry, main window, menu bar, quit protection
│   ├── Models/
│   │   └── Models.swift             # Blocked apps & sites, schedules, session history, saved data
│   ├── Services/
│   │   ├── FocusStore.swift         # Main state: sessions, schedules, passcode checks, stats
│   │   ├── AppBlocker.swift         # Watches app launches and closes blocked apps
│   │   ├── AppCatalog.swift         # App suggestions (open now + common distractions)
│   │   ├── SystemCommands.swift     # /etc/hosts website blocker, Shortcuts runner
│   │   ├── PasscodeManager.swift    # Keychain storage for the passcode hash
│   │   └── Persistence.swift        # Saves data as JSON
│   ├── Views/
│   │   ├── ContentView.swift        # Sidebar and navigation
│   │   ├── OnboardingView.swift     # First-run welcome guide
│   │   ├── SessionView.swift        # Focus screen: start, countdown, session summary
│   │   ├── BlockListView.swift      # Apps and websites
│   │   ├── SchedulesView.swift      # Schedules and the schedule editor
│   │   ├── SettingsView.swift       # Passcode, notifications, login, troubleshooting
│   │   ├── MenuBarView.swift        # Menu-bar window
│   │   ├── UnlockPanel.swift        # Window shown when a blocked app is opened
│   │   └── Components.swift         # Shared pieces: tiles, chips, progress ring, stats
│   └── Assets.xcassets              # App icon, menu-bar icons, accent color
└── Branding/                        # Logo files and the icon drawing script
```

## Where data is stored

| What | Where |
|---|---|
| Block lists, schedules, settings, session history | `~/Library/Application Support/Undistra/data.json` |
| Passcode (salted hash only) | Keychain, service `com.miy33t.Undistra` |
| Website block | A section in `/etc/hosts` between `# >>> Undistra BEGIN` and `# <<< Undistra END` |

Undistra makes no network requests and collects no analytics. Everything stays on your Mac.

## Testing

There are no automated tests yet. To test by hand, block a harmless app such as **Calculator** (don't test with apps holding unsaved work, because they're force-quit), then:

| Test | Expected result |
|---|---|
| Start a 5-minute session | Admin password prompt, then the countdown and progress ring |
| Open Calculator | It closes and the unlock window appears |
| Enter a wrong passcode 3 times | "2 attempts left", "1 attempt left", then a 60-second lockout |
| Unlock for 5 minutes | Calculator opens, then closes again after 5 minutes |
| Open a blocked website | The page doesn't load |
| Try to quit or remove an item | Refused / greyed out |
| Add a schedule starting 1 minute from now | Focus turns on by itself |
| Let a session finish | "Session complete" card with a sound, and stats update |

Check the website block from the terminal:
```bash
grep -A4 "Undistra BEGIN" /etc/hosts
dscacheutil -q host -a name youtube.com   # should show 0.0.0.0
```

## Troubleshooting

**A blocked website still loads**
- Quit the browser fully (⌘Q) and open it again. Browsers reuse open connections.
- In Chrome, turn off **Settings → Privacy and security → Use secure DNS**.
- If you cancelled the password prompt, press **Settings → Apply Website Block Again**.

**Do Not Disturb doesn't turn on**
- Check that the shortcut names in Settings exactly match the names in the Shortcuts app.
- Press **Test On** to see the error message.

**Emergency and reset commands**
```bash
# Quit Undistra, even during a session
pkill -x Undistra

# Remove a website block that got stuck
sudo sed -i '' '/# >>> Undistra BEGIN/,/# <<< Undistra END/d' /etc/hosts && sudo killall -HUP mDNSResponder

# Delete all data and the passcode (start fresh)
rm -rf ~/Library/Application\ Support/Undistra
security delete-generic-password -s com.miy33t.Undistra -a passcode
```

## Design principles
The design uses behavioral psychology *ethically*: it makes the focused choice easy, without tricking or shaming you.

| Principle | Where it's used |
|---|---|
| **Default effect** | "Stay Focused" is the big default button. Unlocking defaults to the shortest time. |
| **Ethical friction** | Unlocking sits behind "I really need it…" and a passcode. Possible, but never a reflex. |
| **Commitment and consistency** | Writing down your task and seeing it again when you're tempted. |
| **Goal gradient** | The progress ring fills as you get closer to the end. |
| **Recognition over recall** | App suggestions and website categories instead of empty forms. |
| **Progressive commitment** | The welcome guide gives value first (pick distractions) before asking for a passcode. |
| **Peak-end rule** | A rewarding "Session complete" moment. Ending early says "That still counts", never shames. |

## Brand

| File | Use |
|---|---|
| `Branding/undistra-icon.svg` · `undistra-icon-1024.png` | App icon for the website, App Store and social media |
| `Branding/undistra-mark.svg` | Just the U and dot, on a transparent background |
| `Branding/undistra-logo-horizontal.svg` | Mark plus the "undistra" wordmark, for headers |
| `Branding/render-icon.swift` | Draws the app icon and menu-bar icons |

**Logo idea:** the **U** holds a single glowing dot, your one focus, while faded dots (distractions) drift away.

**Colors**

| Coral | Pink (accent) | Violet | Text |
|---|---|---|---|
| `#FF7A45` | `#FF2D7A` | `#7A3CF0` | `#1D1B2E` |

To change the icon, edit `Branding/render-icon.swift`, then run:
```bash
swift Branding/render-icon.swift
```

## Known limits and roadmap

**Current limits**
- Changing the website block asks for your admin password each time.
- An admin can still force-quit Undistra or edit `/etc/hosts` by hand.
- Browsers with **Secure DNS** (DNS over HTTPS) can skip the website block.
- Schedules only run while the app is open.

**Ideas for the future**
- [ ] A privileged helper (`SMAppService.daemon`): no more password prompts, and blocking survives a force-quit
- [ ] A Network Extension content filter, so blocking also works with Secure DNS
- [ ] Automated tests for schedules, address cleanup, `/etc/hosts` editing and passcode lockout
- [ ] Break reminders between sessions (Pomodoro mode)
- [ ] Weekly stats and focus history charts
- [ ] Apple's Screen Time APIs (`FamilyControls` / `ManagedSettings`), which need an Apple-approved entitlement
