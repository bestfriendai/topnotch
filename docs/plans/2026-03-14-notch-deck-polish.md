# Notch Deck Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the expanded notch deck feel cleaner and more predictable by remembering the last card, refining swipe behavior, and improving deck header/card hierarchy.

**Architecture:** Keep the deck UI in `MyDynamicIsland/IslandView.swift`, but extract pure deck paging helpers into a small standalone file so swipe thresholds, edge resistance, and target-card resolution can be tested without UI coupling. Add a minimal macOS unit test target because the project currently has no automated tests.

**Tech Stack:** Swift, SwiftUI, Xcode project configuration, XCTest

---

### Task 1: Add a Minimal Test Target for Deck Logic

**Files:**
- Modify: `MyDynamicIsland.xcodeproj/project.pbxproj`
- Create: `MyDynamicIslandTests/DeckPagingLogicTests.swift`

**Step 1: Write the failing test**

Create a unit test file that references a yet-to-be-created deck paging helper type and asserts that a drag below threshold keeps the current index.

```swift
import XCTest
@testable import Top_Notch

final class DeckPagingLogicTests: XCTestCase {
    func testSmallDragKeepsCurrentIndex() {
        let result = DeckPagingLogic.targetIndex(
            currentIndex: 1,
            cardCount: 4,
            translationWidth: -20,
            predictedEndTranslationWidth: -24,
            pageWidth: 320
        )

        XCTAssertEqual(result, 1)
    }
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -destination 'platform=macOS' test
```

Expected: FAIL because the test target or `DeckPagingLogic` does not exist yet.

**Step 3: Add the test target wiring**

Update the Xcode project to include a minimal macOS unit test target that can import the app module.

**Step 4: Run test to verify it still fails for the right reason**

Run the same command.

Expected: FAIL because `DeckPagingLogic` is still undefined, which proves the test target is now wired correctly.

**Step 5: Commit**

```bash
git add MyDynamicIsland.xcodeproj/project.pbxproj MyDynamicIslandTests/DeckPagingLogicTests.swift
git commit -m "test: add notch deck paging test target"
```

### Task 2: Extract and Test Deck Paging Logic

**Files:**
- Create: `MyDynamicIsland/DeckPagingLogic.swift`
- Modify: `MyDynamicIslandTests/DeckPagingLogicTests.swift`

**Step 1: Write the failing tests**

Add focused tests for:

- small drag keeps current index
- strong left drag advances one card
- strong right drag goes back one card
- edges clamp to first and last card

```swift
func testStrongLeftDragAdvancesToNextCard() {
    let result = DeckPagingLogic.targetIndex(
        currentIndex: 1,
        cardCount: 4,
        translationWidth: -100,
        predictedEndTranslationWidth: -140,
        pageWidth: 320
    )

    XCTAssertEqual(result, 2)
}
```

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -destination 'platform=macOS' test
```

Expected: FAIL because `DeckPagingLogic` is not implemented.

**Step 3: Write minimal implementation**

Create a pure helper type with functions for:

- resolving target index
- applying drag resistance near boundaries

Keep it independent from SwiftUI view state.

**Step 4: Run tests to verify they pass**

Run the same command.

Expected: PASS for the new deck logic tests.

**Step 5: Commit**

```bash
git add MyDynamicIsland/DeckPagingLogic.swift MyDynamicIslandTests/DeckPagingLogicTests.swift
git commit -m "feat: add tested notch deck paging logic"
```

### Task 3: Persist the Last Active Deck Card

**Files:**
- Modify: `MyDynamicIsland/IslandView.swift`
- Test: `MyDynamicIslandTests/DeckPagingLogicTests.swift`

**Step 1: Write the failing test**

Add a small pure mapping test for converting stored raw values into valid deck indices or safe defaults. If needed, extend `DeckPagingLogic` with a helper that sanitizes persisted selection.

```swift
func testInvalidStoredDeckIndexFallsBackToHome() {
    let result = DeckPagingLogic.sanitizedIndex(storedIndex: 99, cardCount: 4)
    XCTAssertEqual(result, 0)
}
```

**Step 2: Run tests to verify it fails**

Run the same `xcodebuild ... test` command.

Expected: FAIL because the sanitizing helper is not implemented yet.

**Step 3: Write minimal implementation**

- Add the helper in `DeckPagingLogic.swift`
- Store the active card selection in `IslandView.swift` using app storage
- Rehydrate the deck on appear without resetting the user’s last card

**Step 4: Run tests to verify they pass**

Run the same test command.

Expected: PASS.

**Step 5: Commit**

```bash
git add MyDynamicIsland/DeckPagingLogic.swift MyDynamicIsland/IslandView.swift MyDynamicIslandTests/DeckPagingLogicTests.swift
git commit -m "feat: remember last active notch deck card"
```

### Task 4: Refine the Deck Header and Tab Hierarchy

**Files:**
- Modify: `MyDynamicIsland/IslandView.swift`

**Step 1: Write the failing test**

There is no practical UI snapshot test harness in this project yet, so use a build-based failing check for compilation after introducing new helper views. The failure condition is unresolved symbols from the new header structure.

**Step 2: Run build to verify the pre-change state**

Run:

```bash
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -configuration Debug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected: PASS before changes.

**Step 3: Write minimal implementation**

In `IslandView.swift`:

- turn the header tabs into a cleaner segmented-control treatment
- increase active/inactive contrast separation
- move secondary actions into a quieter trailing action zone
- reduce header noise from one-off buttons

**Step 4: Run build to verify it passes**

Run the same build command.

Expected: PASS.

**Step 5: Commit**

```bash
git add MyDynamicIsland/IslandView.swift
git commit -m "feat: polish notch deck header hierarchy"
```

### Task 5: Refine Card Focus, Drag Feedback, and Motion

**Files:**
- Modify: `MyDynamicIsland/IslandView.swift`
- Modify: `MyDynamicIsland/DeckPagingLogic.swift`
- Test: `MyDynamicIslandTests/DeckPagingLogicTests.swift`

**Step 1: Write the failing test**

Add tests for drag resistance and boundary behavior so the card offset logic is proven before UI wiring.

```swift
func testBoundaryResistanceReducesOffsetAtLeadingEdge() {
    let result = DeckPagingLogic.resistedOffset(
        translationWidth: 120,
        currentIndex: 0,
        cardCount: 4
    )

    XCTAssertLessThan(result, 120)
}
```

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -destination 'platform=macOS' test
```

Expected: FAIL because the resistance helper is missing or incomplete.

**Step 3: Write minimal implementation**

- apply resisted drag offsets in the deck gesture path
- tune snap threshold and predicted-end handling
- add stronger active-card focus and more subdued neighboring-card presence
- reduce bounce and use more damped spring values

**Step 4: Run tests and build to verify they pass**

Run:

```bash
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -destination 'platform=macOS' test
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -configuration Debug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -configuration AppStoreDebug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected: PASS.

**Step 5: Commit**

```bash
git add MyDynamicIsland/DeckPagingLogic.swift MyDynamicIsland/IslandView.swift MyDynamicIslandTests/DeckPagingLogicTests.swift
git commit -m "feat: polish notch deck swipe motion"
```

### Task 6: Manual Product Verification

**Files:**
- Modify: `README.md` only if behavior notes need updates

**Step 1: Run the app and verify deck behavior manually**

Check:

- the deck reopens on the last selected card
- tab switching is visually clearer
- swipe thresholds feel more deliberate
- edge resistance is noticeable but not heavy
- the deck still works for Home, Weather, YouTube, and Media cards

**Step 2: Verify both build variants still compile**

Run:

```bash
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -configuration Debug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
xcodebuild -project MyDynamicIsland.xcodeproj -scheme MyDynamicIsland -configuration AppStoreDebug CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected: PASS for both.

**Step 3: Update docs if needed**

Only document user-visible deck behavior changes if the README becomes inaccurate.

**Step 4: Commit**

```bash
git add README.md
git commit -m "docs: update notch deck behavior notes"
```