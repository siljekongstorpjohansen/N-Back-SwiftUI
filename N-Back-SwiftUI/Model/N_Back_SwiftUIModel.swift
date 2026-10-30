//
//  N_Back_SwiftUIModel.swift
//  N-Back-SwiftUI
//
//  Created by Jonas Willén on 2023-09-19.
//
//  The model layer: pure game logic with no UI or timer code, so it can be unit tested.
//

import Foundation

/// Which kind of stimuli the player trains with.
enum StimulusMode: String, CaseIterable, Identifiable {
    case visual
    case auditory
    case dual

    var id: String { rawValue }

    /// Short name shown on the home screen.
    var title: String {
        switch self {
        case .visual: return "Image"
        case .auditory: return "Sound"
        case .dual: return "Both"
        }
    }

    /// SF Symbol shown next to the title.
    var systemImageName: String {
        switch self {
        case .visual: return "eye"
        case .auditory: return "speaker.wave.3.fill"
        case .dual: return "square.grid.3x3.fill"
        }
    }

    var usesVisualStimuli: Bool { self != .auditory }
    var usesAuditoryStimuli: Bool { self != .visual }
}

/// One of the two independent stimulus streams a match can be registered for.
enum StimulusStream {
    case visual
    case auditory
}

/// The values that shape a round. Shown on the home screen and changed on the settings screen.
struct GameSettings: Equatable {
    // Allowed values for each setting the player can change.
    /// Largest n there is room for; the n actually allowed also depends on the round length (see `allowedNRange`).
    static let maxN = 9
    /// Events after the first n (those that can be matches) needed so a 20–40 % share is a whole number of matches.
    /// With 1 or 2 such events every count is 0 % or at least 50 %; from 3 there is always a count in range.
    static let minEligibleEvents = 3
    static let allowedEventsPerRoundRange = 10...60
    static let allowedEventDurationRange: ClosedRange<TimeInterval> = 1.0...5.0
    static let eventDurationStep: TimeInterval = 0.5
    static let allowedGridSizeRange = 3...5
    static let allowedLetterCountRange = 2...allSpokenLetters.count

    /// Phonetically distinct letters, so the player never confuses two of them when spoken.
    /// English letter names fall into groups that rhyme (B C D E G P T V Z / A J K / F L M N S X /
    /// I Y / Q U W); this set takes one letter from each group, plus H, O and R which rhyme with nothing.
    static let allSpokenLetters = ["H", "K", "O", "Q", "R", "S", "T", "Y"]

    /// How each letter is read aloud. Speaking the name as a word stops the voice from saying
    /// "capital H" for an uppercase letter.
    static let letterNames = ["H": "aitch", "K": "kay", "O": "oh", "Q": "cue",
                              "R": "ar", "S": "ess", "T": "tee", "Y": "why"]

    /// How many steps back the player must remember.
    var n: Int = 2
    /// Seconds each event lasts.
    var eventDuration: TimeInterval = 2.0
    /// Number of events in one round.
    var eventsPerRound: Int = 20
    /// Fraction of eligible events (those after the first n) that are matches. Must stay within 0.2–0.4.
    var matchRate: Double = 0.3
    /// The grid is gridSize × gridSize cells.
    var gridSize: Int = 3
    /// How many of `allSpokenLetters` are used in a round.
    var letterCount: Int = 8

    /// Values of n that leave at least `minEligibleEvents` events that can be matches.
    /// With the shortest round (10 events) n goes up to 7; from 12 events up to `maxN`.
    var allowedNRange: ClosedRange<Int> { 1...min(Self.maxN, eventsPerRound - Self.minEligibleEvents) }

    /// The letters used in a round: the first `letterCount` of `allSpokenLetters`.
    var spokenLetters: [String] { Array(Self.allSpokenLetters.prefix(letterCount)) }

    /// A copy with every value moved into its allowed range.
    func validated() -> GameSettings {
        var settings = self
        settings.eventsPerRound = eventsPerRound.clamped(to: Self.allowedEventsPerRoundRange)
        // After eventsPerRound, because the allowed n depends on it. Lowering the round length can lower n.
        settings.n = n.clamped(to: settings.allowedNRange)
        settings.eventDuration = eventDuration.clamped(to: Self.allowedEventDurationRange)
        settings.gridSize = gridSize.clamped(to: Self.allowedGridSizeRange)
        settings.letterCount = letterCount.clamped(to: Self.allowedLetterCountRange)
        return settings
    }
}

/// Generates n-back sequences.
///
/// The raw sequence comes from the skeleton's C generator (`nback.c`). The rules are then
/// checked and enforced here in Swift:
/// - none of the first `n` events can be a match (they have nothing n steps back), and
/// - between 20 % and 40 % of the other events are matches.
///
/// Each value is a stimulus index in `0..<combinations` (a grid cell or a letter).
/// Index `i` is a match when `sequence[i] == sequence[i - n]`.
struct NBackSequenceGenerator {
    static let minMatchRate = 0.2
    static let maxMatchRate = 0.4

    /// - Parameters:
    ///   - length: Number of events in the sequence (at most 100, the size limit in nback.c).
    ///   - n: Distance between two matching events.
    ///   - combinations: Number of distinct stimulus values (must be at least 2).
    ///   - matchRate: Match percentage passed to nback.c.
    ///   - generator: Source of randomness for the corrections made in Swift.
    /// - Returns: The stimulus index for every event.
    static func generate<R: RandomNumberGenerator>(length: Int,
                                                   n: Int,
                                                   combinations: Int,
                                                   matchRate: Double,
                                                   using generator: inout R) -> [Int] {
        precondition(n >= 1, "n must be at least 1")
        precondition(combinations >= 2, "Need at least two stimulus values so a non-match is possible")
        precondition(length <= 100, "nback.c holds at most 100 events")
        guard length > 0 else { return [] }

        // 1. Raw sequence from nback.c.
        var sequence = sequenceFromC(length: length, n: n, combinations: combinations, matchRate: matchRate)

        // 2. Decide exactly which events are matches. Keep the matches nback.c made, then add or
        //    remove random ones until their share of the eligible events (index n and later) is allowed.
        let eligiblePositions = Array(min(n, length)..<length)
        var matchPositions = Set(eligiblePositions.filter { sequence[$0] == sequence[$0 - n] })
        let allowedCount = allowedMatchCount(eligibleCount: eligiblePositions.count)

        var positionsToAdd = eligiblePositions.filter { !matchPositions.contains($0) }.shuffled(using: &generator)
        while matchPositions.count < allowedCount.lowerBound, let position = positionsToAdd.popLast() {
            matchPositions.insert(position)
        }
        var positionsToRemove = Array(matchPositions).shuffled(using: &generator)
        while matchPositions.count > allowedCount.upperBound, let position = positionsToRemove.popLast() {
            matchPositions.remove(position)
        }

        // 3. Go through the events in order and make exactly the chosen ones matches.
        //    nback.c's value is kept wherever it already follows the rule.
        //    The first n events are never touched: they cannot be matches.
        for index in eligiblePositions {
            let valueNBack = sequence[index - n]
            if matchPositions.contains(index) {
                sequence[index] = valueNBack
            } else if sequence[index] == valueNBack {
                // Any value except the one n steps back, so this event is guaranteed not to match.
                var value = Int.random(in: 0..<(combinations - 1), using: &generator)
                if value >= valueNBack { value += 1 }
                sequence[index] = value
            }
        }
        return sequence
    }

    /// Convenience overload that uses the system random generator.
    static func generate(length: Int, n: Int, combinations: Int, matchRate: Double) -> [Int] {
        var generator = SystemRandomNumberGenerator()
        return generate(length: length, n: n, combinations: combinations, matchRate: matchRate, using: &generator)
    }

    /// Calls the C generator and converts its values (1...combinations) to indexes (0..<combinations).
    private static func sequenceFromC(length: Int, n: Int, combinations: Int, matchRate: Double) -> [Int] {
        let matchPercentage = Int32((matchRate * 100).rounded())
        let nback = create(Int32(length), Int32(combinations), matchPercentage, Int32(n))
        defer { destroy(nback) }
        return (0..<length).map { Int(getIndexOf(nback, Int32($0))) - 1 }
    }

    /// Match counts whose share of the eligible events lies within 20–40 %.
    /// Very short rounds may have no such count; then the count closest to 20 % is used.
    static func allowedMatchCount(eligibleCount: Int) -> ClosedRange<Int> {
        let lowest = Int((Double(eligibleCount) * minMatchRate).rounded(.up))
        let highest = Int((Double(eligibleCount) * maxMatchRate).rounded(.down))
        if lowest <= highest {
            return lowest...highest
        }
        let closest = Int((Double(eligibleCount) * minMatchRate).rounded())
        return closest...closest
    }

    /// Returns true when the event at `index` repeats the event n steps back.
    static func isMatch(in sequence: [Int], at index: Int, n: Int) -> Bool {
        index >= n && index < sequence.count && sequence[index] == sequence[index - n]
    }
}

/// The state machine for one round of n-back: idle → running → finished.
struct NBackGame {

    enum Phase: Equatable {
        case idle
        case running
        case finished
    }

    /// What happened when the player pressed a match button.
    enum MatchPressResult: Equatable {
        /// The press was not counted: wrong phase, within the first n events, stream not in use, or already pressed this event.
        case ignored
        case correct
        case incorrect
    }

    private(set) var phase: Phase = .idle
    private(set) var settings = GameSettings()
    private(set) var mode: StimulusMode = .visual
    private(set) var visualSequence: [Int] = []
    private(set) var auditorySequence: [Int] = []

    /// Index of the event being shown, or -1 before the first event.
    private(set) var currentEventIndex = -1
    /// Correct match presses.
    private(set) var hits = 0
    /// Match presses on events that were not matches.
    private(set) var falseAlarms = 0
    /// Matches the player let pass without pressing.
    private(set) var misses = 0

    /// Streams the player has already pressed for during the current event (prevents double presses).
    private var pressedStreamsThisEvent: Set<StimulusStream> = []

    /// 1-based event number for the HUD (0 before the first event).
    var currentEventNumber: Int { currentEventIndex + 1 }

    /// Final score: correct presses minus false alarms, never below zero.
    var score: Int { max(0, hits - falseAlarms) }

    /// Starts a new round with fresh sequences for the streams the mode uses.
    mutating func start(settings: GameSettings, mode: StimulusMode) {
        self.settings = settings
        self.mode = mode
        let cellCount = settings.gridSize * settings.gridSize
        visualSequence = mode.usesVisualStimuli
            ? NBackSequenceGenerator.generate(length: settings.eventsPerRound, n: settings.n,
                                              combinations: cellCount, matchRate: settings.matchRate)
            : []
        auditorySequence = mode.usesAuditoryStimuli
            ? NBackSequenceGenerator.generate(length: settings.eventsPerRound, n: settings.n,
                                              combinations: settings.spokenLetters.count, matchRate: settings.matchRate)
            : []
        currentEventIndex = -1
        hits = 0
        falseAlarms = 0
        misses = 0
        pressedStreamsThisEvent = []
        phase = .running
    }

    /// Moves to the next event. Counts unpressed matches of the event that just ended as misses.
    /// Ends the round when there are no more events.
    mutating func advanceToNextEvent() {
        guard phase == .running else { return }
        countMissesForCurrentEvent()
        currentEventIndex += 1
        pressedStreamsThisEvent = []
        if currentEventIndex >= settings.eventsPerRound {
            currentEventIndex = settings.eventsPerRound - 1
            phase = .finished
        }
    }

    /// Ends the round early, for example when the player leaves the game screen.
    mutating func stop() {
        guard phase == .running else { return }
        phase = .finished
    }

    /// Registers a match press for one stream on the current event.
    mutating func registerMatch(for stream: StimulusStream) -> MatchPressResult {
        guard phase == .running,
              currentEventIndex >= settings.n,
              isStreamInUse(stream),
              !pressedStreamsThisEvent.contains(stream) else {
            return .ignored
        }
        pressedStreamsThisEvent.insert(stream)
        if NBackSequenceGenerator.isMatch(in: sequence(for: stream), at: currentEventIndex, n: settings.n) {
            hits += 1
            return .correct
        } else {
            falseAlarms += 1
            return .incorrect
        }
    }

    /// Grid cell to highlight for the current event, if the mode is visual.
    var currentGridCell: Int? {
        guard mode.usesVisualStimuli, visualSequence.indices.contains(currentEventIndex) else { return nil }
        return visualSequence[currentEventIndex]
    }

    /// Letter to speak for the current event, if the mode is auditory.
    var currentLetter: String? {
        guard mode.usesAuditoryStimuli, auditorySequence.indices.contains(currentEventIndex) else { return nil }
        return settings.spokenLetters[auditorySequence[currentEventIndex]]
    }

    private func isStreamInUse(_ stream: StimulusStream) -> Bool {
        switch stream {
        case .visual: return mode.usesVisualStimuli
        case .auditory: return mode.usesAuditoryStimuli
        }
    }

    private func sequence(for stream: StimulusStream) -> [Int] {
        switch stream {
        case .visual: return visualSequence
        case .auditory: return auditorySequence
        }
    }

    private mutating func countMissesForCurrentEvent() {
        for stream in [StimulusStream.visual, .auditory] where isStreamInUse(stream) {
            if NBackSequenceGenerator.isMatch(in: sequence(for: stream), at: currentEventIndex, n: settings.n),
               !pressedStreamsThisEvent.contains(stream) {
                misses += 1
            }
        }
    }
}

/// Saves and loads the player's chosen settings in UserDefaults.
struct GameSettingsStore {
    private let defaults: UserDefaults
    private let nKey = "settings.n"
    private let eventsPerRoundKey = "settings.eventsPerRound"
    private let eventDurationKey = "settings.eventDuration"
    private let gridSizeKey = "settings.gridSize"
    private let letterCountKey = "settings.letterCount"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns the saved settings, or the defaults for anything never saved.
    func load() -> GameSettings {
        var settings = GameSettings()
        if defaults.object(forKey: nKey) != nil {
            settings.n = defaults.integer(forKey: nKey)
        }
        if defaults.object(forKey: eventsPerRoundKey) != nil {
            settings.eventsPerRound = defaults.integer(forKey: eventsPerRoundKey)
        }
        if defaults.object(forKey: eventDurationKey) != nil {
            settings.eventDuration = defaults.double(forKey: eventDurationKey)
        }
        if defaults.object(forKey: gridSizeKey) != nil {
            settings.gridSize = defaults.integer(forKey: gridSizeKey)
        }
        if defaults.object(forKey: letterCountKey) != nil {
            settings.letterCount = defaults.integer(forKey: letterCountKey)
        }
        // Guards against values saved by an older version with different limits.
        return settings.validated()
    }

    func save(_ settings: GameSettings) {
        defaults.set(settings.n, forKey: nKey)
        defaults.set(settings.eventsPerRound, forKey: eventsPerRoundKey)
        defaults.set(settings.eventDuration, forKey: eventDurationKey)
        defaults.set(settings.gridSize, forKey: gridSizeKey)
        defaults.set(settings.letterCount, forKey: letterCountKey)
    }
}

extension Comparable {
    /// Returns the value limited to `range`.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Saves and loads the high score in UserDefaults.
struct HighScoreStore {
    private let defaults: UserDefaults
    private let key = "highScore"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Int {
        defaults.integer(forKey: key)
    }

    /// Saves `score` if it beats the stored high score. Returns the high score after saving.
    @discardableResult
    func saveIfHigher(_ score: Int) -> Int {
        let best = max(load(), score)
        defaults.set(best, forKey: key)
        return best
    }
}
