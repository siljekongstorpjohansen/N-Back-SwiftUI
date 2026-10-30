# CONTEXT — course constraints

Give this file, `SPEC.md` and `STYLE.md` to the LLM at the start of every session.

## Course
- Lab B:1, HI1033 / CM2023, KTH. Solved individually.
- Starting point: the skeleton `JonasWillen/N-Back-SwiftUI` (SwiftUI + the C file `nback.c`).
- Every line must be explainable at the oral exam, whether written by a person or an LLM.
- All AI assistance must be noted in the submission.

## Hard constraints
- **No external libraries beyond the platform SDK.** Only Apple frameworks: SwiftUI, Foundation,
  AVFoundation, XCTest. No Swift packages, CocoaPods or copied third-party code.
- **Architecture: MVVM.** Appropriate classes; no single god-class. See `STYLE.md`.
- **Sequence rules are our own code.** `nback.c` may produce the raw sequence, but the 20–40 % match
  rate and the first-n guarantee are enforced in Swift (`NBackSequenceGenerator`).
- **Unit tests must run and pass** on the submitted code (`xcodebuild test`, or ⌘U in Xcode).
- Settings in `UserDefaults`; text-to-speech with one `AVSpeechSynthesizer` created once.
- Must work on iPhone and iPad, portrait and landscape.

## "Single-file preferred"
Interpreted as **one file per MVVM layer**, not one file for the whole app (that would conflict with
"structured in appropriate classes"):

| File | Layer | Contents |
|---|---|---|
| `Model/N_Back_SwiftUIModel.swift` | Model | Settings, sequence generator, round state machine, storage |
| `N_Back_SwiftUIVM.swift` | ViewModel | `N_Back_SwiftUIVM` |
| `View/Views.swift` | View | All SwiftUI screens and their small helper views |
| `N_Back_SwiftUIApp.swift` | App entry | `@main`; creates the ViewModel |
| `Model/nback.c`, `nback.h` | Model (C) | Skeleton generator; C cannot live in a Swift file |
| `N-Back-SwiftUITests/N_Back_SwiftUITests.swift` | Tests | All unit tests |

New code goes into the existing file for its layer; do not add new files unless there is a new layer.

## Output wanted from the LLM
- Complete, compiling Swift that fits into the file for its layer.
- Documentation comments (`///`) on every type and on non-obvious methods and properties.
- Explain *why* in comments, not *what*.
- Point out when a request conflicts with these constraints instead of silently breaking them.
