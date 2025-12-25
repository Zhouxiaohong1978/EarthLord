# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EarthLord (地球新主) is a pure SwiftUI iOS application with an apocalypse-themed UI. The app uses MVVM architecture with TabView navigation.

## Build and Run

Open `EarthLord.xcodeproj` in Xcode and run with Cmd+R. No additional setup required.

- **Minimum iOS:** 16.6
- **Swift Version:** 5.0
- **Bundle ID:** com.zhouxiaohong.EarthLord

## Architecture

```
EarthLordApp (@main)
└── RootView (controls splash → main transition)
    ├── SplashView (animated loading screen, 2.5s)
    └── MainTabView (4-tab navigation)
        ├── MapTabView      - 地图 (map.fill)
        ├── TerritoryTabView - 领地 (flag.fill)
        ├── ProfileTabView   - 个人 (person.fill)
        └── MoreTabView      - 更多 (ellipsis)
```

## Project Structure

```
EarthLord/
├── EarthLordApp.swift          # App entry point → RootView
├── ContentView.swift           # Backup entry (→ MainTabView)
├── Theme/
│   └── ApocalypseTheme.swift   # Color definitions (末日主题配色)
├── Components/
│   └── PlaceholderView.swift   # Reusable placeholder component
└── Views/
    ├── RootView.swift          # Splash → Main transition controller
    ├── SplashView.swift        # Animated splash with breathing effect
    ├── MainTabView.swift       # TabView with 4 tabs
    └── Tabs/
        ├── MapTabView.swift
        ├── TerritoryTabView.swift
        ├── ProfileTabView.swift
        └── MoreTabView.swift
```

## Theme Colors (ApocalypseTheme)

All UI colors are defined in `Theme/ApocalypseTheme.swift`:
- `background` - Near black (#141416)
- `primary` - Orange (#FF6619)
- `textPrimary` - White
- `textSecondary` - Gray (60% white)
- Status colors: `success`, `warning`, `danger`, `info`

## Code Conventions

- All user-visible text uses `LocalizedStringKey` for i18n support
- Each view file includes `#Preview` macro
- Colors must use `ApocalypseTheme` constants, not hardcoded values
- UI text is in Chinese (简体中文)
