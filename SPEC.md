# SPEC — N-Back app (Lab B:1, HI1033 / CM2023)

A native n-back working-memory game. A sequence of stimuli is shown one at a time; the player
presses a match button when the current stimulus is the same as the one exactly **n** steps earlier.
Dual n-back shows two independent sequences at once (a grid cell and a spoken letter).

## Platform choice

| | |
|---|---|
| Platform | iOS (iPhone and iPad) |
| Language | Swift 5 |
| UI framework | SwiftUI |
| IDE | Xcode |
| Minimum iOS | 16.4 |
| Orientations | Portrait, upside-down portrait\*, landscape left and right |

\* iPhones with Face ID never rotate to upside-down portrait; iOS blocks it for all apps.

Why iOS/SwiftUI: the course skeleton (`JonasWillen/N-Back-SwiftUI`) is a SwiftUI project, and
`AVSpeechSynthesizer` and `UserDefaults` give text-to-speech and settings storage without any
external library.

## Screens

1. **Home screen**
   - Shows the current high score.
   - Lets the player choose visual stimuli, auditory stimuli, or both.
   - Shows the current settings: stimulus type, n, event duration, events per round
     (plus grid size and number of letters when relevant).
   - Buttons to start the game and to open the settings screen.
2. **Game screen**
   - Shows the grid for visual stimuli and/or plays spoken letters for auditory stimuli.
   - Shows live state: current event number and correct responses so far.
   - One match button per stimulus stream in use, and a button to start/restart a round.
   - Gives non-offensive animated feedback on an incorrect press (the button gently shakes and
     turns orange for a moment).
   - When a round has been played to the end, a popup shows correct matches, missed matches,
     wrong matches and the score (plus "New high score!" when beaten). It closes with the Close
     button or a tap outside it. It is not shown when the player leaves mid-round.
3. **Settings screen** (persistent)
   - Events per round, event duration, n, grid size (3×3 to 5×5), number of distinct spoken letters.

## Mandatory requirements (all needed to pass)

- [x] Visual stimuli in a 3×3 grid (default; settings allow up to 5×5); one cell highlighted per event.
- [x] Auditory stimuli as spoken letters from a fixed, phonetically distinct set.
- [x] Controls to start a new round and to register an n-back match.
- [x] Home screen shows stimulus type, n, event duration, events per round.
- [x] Game screen shows the current event number and the number of correct responses.
- [x] Non-offensive animated feedback on an incorrect match press (colour + gentle shake on the button).
- [x] A match press is ignored before the round starts, after it ends, and during the first n events.
- [x] Multiple match presses on the same event are ignored after the first.
- [x] The round timer is cancelled cleanly when the round ends or the player leaves the screen mid-round.
- [x] Sequence logic implemented by us, not delegated entirely to a library:
      match rate 20–40 %, and the first n events can never be matches.
- [x] Unit tests for at least three of: sequence generation, match-rate enforcement, first-n guarantee,
      double-press prevention, scoring formula. Tests must run and pass.

## Higher-level requirements (for full marks)

- [x] Dual n-back (visual and auditory at the same time).
- [x] Settings screen (persistent) — stored in `UserDefaults`.
- [ ] Score history with names and a local database — **not implemented** (optional; three of four are enough).
- [x] Responsive layout — portrait and landscape, phone and tablet.
- [x] Accessibility — match button at least 44 pt tall (72 pt used); a fallback message when no
      text-to-speech voice is available.

## Game rules

### Sequence
- Each round has `eventsPerRound` events; each event has a stimulus index per stream in use
  (a grid cell `0..<gridSize²`, or a letter index `0..<letterCount`).
- Event `i` is a **match** when `sequence[i] == sequence[i - n]`.
- Events `0..<n` can never be matches (there is nothing n steps back).
- Between 20 % and 40 % of the events from index n onward are matches.
- n is limited to `eventsPerRound − 3`, so at least 3 events can be matches and a 20–40 % share
  is always a whole number of matches.
- The raw sequence comes from the skeleton's C generator `nback.c`; Swift code enforces both rules.

### Round state machine
`idle → running → finished` (and `running → finished` when the player leaves mid-round).
Starting a new round from any state goes to `running` with fresh sequences.

### Scoring
- **Hit**: match press on a match event.
- **False alarm**: match press on a non-match event.
- **Miss**: a match event that ended without a press.
- **Score** = hits − false alarms, never below 0. The high score is the best score so far.

## Spoken letters
H, K, O, Q, R, S, T, Y: one letter from each group of English letter names that rhyme, so no two
sound alike. Each letter is spoken by its English name ("aitch", "kay", …) with an English voice,
so the voice never says "capital".
