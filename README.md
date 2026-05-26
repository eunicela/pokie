# Poker Trainer

A local-only SwiftUI iOS 17 poker trainer for learning exploitative Texas Hold'em.

## What is included

- Six-max No-Limit Hold'em table: one human seat and five stable AI archetypes.
- Pure Swift rules engine with legal betting flow, rotating blinds, showdown, hand evaluation, split pots, and side pots.
- AI opponents tuned as TAG, LAG, Rock, and Fish rather than solver-style bots.
- Dark, minimalist SwiftUI app with table, hand-rankings sheet, showdown reveal/coaching, stats, and profile tabs.
- SwiftData-backed player stat persistence.
- Always-free chip recharge from the profile screen and table when your stack is low.
- Unit tests for hand evaluation and unequal-stack side-pot distribution.

## Opening the app

Open `PokerTrainer.xcodeproj` in Xcode 16 or newer and run the `PokerTrainer` scheme on an iOS 17+ simulator or device.

The pure rules package can also be opened with Swift Package Manager for `PokerTrainerCore` and its tests.

## Test focus

The key acceptance coverage is in `Tests/PokerTrainerCoreTests/SidePotCalculatorTests.swift`, including a multi-way all-in hand with unequal stacks and a folded contributor.
