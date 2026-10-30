# STYLE — architecture decisions

## MVVM layers

```
View (SwiftUI)  ──calls──▶  ViewModel  ──calls──▶  Model
      ▲                         │
      └──── @Published ─────────┘
```

| Layer | May do | Must not do |
|---|---|---|
| **Model** (`N_Back_SwiftUIModel.swift`, `nback.c`) | Game rules, sequence generation, scoring, the round state machine, saving/loading with `UserDefaults` | Import SwiftUI; know about screens, timers or speech |
| **ViewModel** (`N_Back_SwiftUIVM.swift`) | Own the model, run the round timer, speak letters, publish state, prepare every text the views show | Import SwiftUI; navigate between screens |
| **View** (`Views.swift`) | Lay out what the ViewModel publishes, forward taps to it, own purely visual state (animations, navigation flags) | Contain game logic, decide texts from game state, format values |

### Why
- The Model has no UI or timer code, so it is tested directly with XCTest.
- The ViewModel does not navigate: navigation is UI state (`@State` in `HomeView`), so the same
  ViewModel works for any screen layout and needs no reference to views.

## Key decisions

- **One ViewModel** (`N_Back_SwiftUIVM`) for the whole app, created once in `N_Back_SwiftUIApp` and
  shared with `.environmentObject`. The app is small; one source of truth avoids syncing settings
  between screens.
- **Round state machine in the Model** (`NBackGame`: `idle → running → finished`). All press rules
  (before start, after end, first n events, double press) live in `registerMatch(for:)`, so they are
  unit-testable without a UI.
- **Round timer**: a Swift `Task` in the ViewModel (`runRound()`), cancelled in `cancelRoundTimer()`
  when the round ends, restarts, or the game screen disappears (`leaveGame()` from `onDisappear`).
- **Sequence generation**: `nback.c` creates the raw sequence; `NBackSequenceGenerator` (Swift)
  enforces 20–40 % matches and the first-n guarantee. Randomness is injectable for tests.
- **Text-to-speech**: one `AVSpeechSynthesizer`, created once in the ViewModel. Letters are spoken by
  name ("kay") with an `en-US` voice. If no voice exists the game screen shows a message and the
  letter as text instead.
- **Persistence**: settings and high score in `UserDefaults` via small store types in the Model
  (`GameSettingsStore`, `HighScoreStore`). Settings are validated on every load and save.
- **Display values**: the ViewModel exposes ready-made strings (`eventDurationText`, `gameTitle`,
  `startButtonTitle`, …) so views never format or decide text.
- **Responsive layout**: views choose a side-by-side layout when the screen is wider than tall
  (game screen) or the height is compact (home screen). The grid keeps `aspectRatio(1)`.

## Naming
- Types: `UpperCamelCase` nouns (`GameSettings`, `NBackGame`, `StimulusGridView`).
- Methods: verbs describing the action (`startRound()`, `registerMatch(for:)`, `leaveGame()`).
- Booleans read as questions (`isRoundRunning`, `showsVisualStimuli`, `usesAuditoryStimuli`).
- Skeleton names are kept (`N_Back_SwiftUIVM`, `N_BackSwiftUIModel` file) so the code is easy to
  compare with the course skeleton.

## Documentation
- `///` comment on every type, and on methods and properties whose purpose is not obvious from the name.
- Each file starts with a header comment saying which layer it is and what it contains.
- Comments explain *why* (e.g. why the cell goes dark before the next event), not *what*.

## Testing
- Unit tests in `N-Back-SwiftUITests/N_Back_SwiftUITests.swift` (XCTest), run with ⌘U.
- Covered: sequence generation, match-rate enforcement, first-n guarantee, double-press prevention,
  presses before start / after end / during the first n events, scoring formula, settings validation.
