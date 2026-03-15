# Notch Deck Polish Design

**Date:** 2026-03-14

## Goal

Polish the expanded notch deck so it feels more intentional, more predictable, and more Apple-like without changing the current feature set.

## Scope

This pass focuses on interaction quality and visual hierarchy for the existing deck:

- Home
- Weather
- YouTube
- Media

It does not add new cards or solve YouTube embed reliability.

## Interaction Model

- The expanded notch remains a horizontal pager.
- Normal expansion reopens the last selected card instead of resetting to Home.
- Home remains the visual anchor of the system, but it is not a forced landing page.
- Swipe transitions should feel more deliberate, with firmer thresholds and subtle drag resistance.
- Tab taps should animate directly and clearly to the selected card.
- Page indicators should become quieter, with a clearer active state and less visual competition.

## UI Direction

- The top tab row should read as a cleaner segmented control.
- The active tab should receive stronger emphasis through fill, contrast, and icon/text clarity.
- Inactive tabs should recede more aggressively.
- The active card should feel dominant during drag and after snap.
- Adjacent cards should feel secondary instead of appearing like a basic shifted stack.
- Card chrome should remain glass-like, but with subtler gradients and lower border contrast.
- Spacing across Home, Weather, YouTube, and Media should be normalized so the deck feels like one product surface.

## Motion Direction

- Tab changes should use a quick spring with less playful bounce.
- Dragging should include resistance near the ends of the deck.
- Snap completion should feel damped and controlled.
- Secondary header actions such as collapse and clipboard shortcuts should be visually quieter and grouped more cleanly.

## Technical Direction

- Keep implementation primarily inside `MyDynamicIsland/IslandView.swift`.
- Persist the last active card using local state storage so reopen behavior is predictable.
- Extract small pure helpers for deck metrics and drag resolution so swipe behavior becomes easier to test.
- Add a lightweight test target for those pure helpers because the project currently has no automated test target.

## Success Criteria

- Expanding the notch reopens the previously used card.
- Swiping feels more deliberate and less loose.
- Tab selection and card focus are visually clearer.
- The deck header is cleaner and less noisy.
- The deck chrome and spacing feel consistent across all cards.
- The app still builds in both direct and App Store configurations after the polish pass.

## Out of Scope

- New deck cards
- New external integrations
- YouTube playback reliability fixes
- Media architecture changes outside what is needed for deck polish