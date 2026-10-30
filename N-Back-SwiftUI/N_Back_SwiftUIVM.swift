//
//  N_Back_SwiftUIVM.swift
//  N-Back-SwiftUI
//
//  Created by Jonas Willén on 2023-09-19.
//
//  The view model: owns the game model, runs the round timer, speaks letters,
//  and publishes the state the views show. It never navigates; the views decide that.
//

import Foundation
import AVFoundation

@MainActor
class N_Back_SwiftUIVM : ObservableObject  {
    /// Created once and reused for every spoken letter.
    private let synthesizer = AVSpeechSynthesizer()
    /// English voice for the letter names, or any English voice if en-US is missing.
    /// nil when the device has no English voice; the letters are then shown on screen instead.
    private let letterVoice: AVSpeechSynthesisVoice? =
        AVSpeechSynthesisVoice(language: "en-US")
        ?? AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("en") }
    private let highScoreStore = HighScoreStore()
    private let settingsStore = GameSettingsStore()
    private var game = NBackGame()
    /// The running round loop. Cancelled when the round ends or the player leaves the game screen.
    private var roundTask: Task<Void, Never>?

    // Home screen state
    @Published private(set) var highScore: Int
    @Published private(set) var settings: GameSettings
    @Published var selectedMode: StimulusMode = .visual

    // Game screen state
    @Published private(set) var phase: NBackGame.Phase = .idle
    @Published private(set) var currentEventNumber = 0
    @Published private(set) var correctResponses = 0
    @Published private(set) var missedMatches = 0
    @Published private(set) var wrongMatches = 0
    @Published private(set) var score = 0
    /// True from the end of a round until the player closes the round summary.
    @Published private(set) var showsRoundSummary = false
    /// True when the round that just ended beat the previous high score.
    @Published private(set) var isNewHighScore = false
    /// Grid cell lit up right now, or nil between events.
    @Published private(set) var highlightedCell: Int?
    /// Letter shown on screen during an event when no voice can speak it (speech fallback).
    @Published private(set) var displayedLetter: String?
    /// Bumped on every incorrect press for a stream; the view animates when it changes.
    @Published private(set) var visualMistakeCount = 0
    @Published private(set) var auditoryMistakeCount = 0

    init(){
        highScore = highScoreStore.load()
        settings = settingsStore.load()
        // Play spoken letters even when the phone's silent switch is on.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }

    /// Replaces the settings with valid values and saves them for next time.
    func updateSettings(_ newSettings: GameSettings) {
        let validSettings = newSettings.validated()
        guard validSettings != settings else { return }
        settings = validSettings
        settingsStore.save(validSettings)
    }

    /// Puts every setting back to its default value.
    func resetSettings() {
        updateSettings(GameSettings())
    }

    /// Starts a new round in the selected mode. Restarts if a round is already running.
    func startRound() {
        cancelRoundTimer()
        showsRoundSummary = false
        game.start(settings: settings, mode: selectedMode)
        publishGameState()
        roundTask = Task { [weak self] in
            await self?.runRound()
        }
    }

    /// Stops the round and its timer. Called when the player leaves the game screen.
    func leaveGame() {
        cancelRoundTimer()
        game.stop()
        // The summary is only for rounds played to the end.
        showsRoundSummary = false
        highlightedCell = nil
        displayedLetter = nil
        publishGameState()
    }

    /// Closes the round summary popup.
    func dismissRoundSummary() {
        showsRoundSummary = false
    }

    /// Registers the player's match press for one stream and triggers feedback if it was wrong.
    func registerMatch(for stream: StimulusStream) {
        let result = game.registerMatch(for: stream)
        if result == .incorrect {
            switch stream {
            case .visual: visualMistakeCount += 1
            case .auditory: auditoryMistakeCount += 1
            }
        }
        publishGameState()
    }

    /// One tick per event: advance → show cell → speak letter → update HUD, until the round is over.
    private func runRound() async {
        let eventNanoseconds = UInt64(settings.eventDuration * 1_000_000_000)
        // The cell goes dark briefly at the end of each event, so two equal cells in a row are visible as two events.
        let visibleNanoseconds = eventNanoseconds * 8 / 10

        while !Task.isCancelled {
            game.advanceToNextEvent()
            guard game.phase == .running else { break }

            highlightedCell = game.currentGridCell
            if let letter = game.currentLetter {
                if isSpeechAvailable {
                    speak(GameSettings.letterNames[letter] ?? letter.lowercased())
                } else {
                    displayedLetter = letter
                }
            }
            publishGameState()

            try? await Task.sleep(nanoseconds: visibleNanoseconds)
            guard !Task.isCancelled else { return }
            highlightedCell = nil
            displayedLetter = nil
            try? await Task.sleep(nanoseconds: eventNanoseconds - visibleNanoseconds)
        }

        guard !Task.isCancelled else { return }
        finishRound()
    }

    private func finishRound() {
        roundTask = nil
        highlightedCell = nil
        displayedLetter = nil
        isNewHighScore = game.score > highScore
        highScore = highScoreStore.saveIfHigher(game.score)
        publishGameState()
        showsRoundSummary = true
    }

    private func cancelRoundTimer() {
        roundTask?.cancel()
        roundTask = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Copies the model's values into the published properties the views observe.
    private func publishGameState() {
        phase = game.phase
        currentEventNumber = game.currentEventNumber
        correctResponses = game.hits
        missedMatches = game.misses
        wrongMatches = game.falseAlarms
        score = game.score
    }

    // Display values
    // Everything the views show is prepared here, so the views only lay it out.

    /// Settings of the round on the game screen: the chosen ones before a round starts,
    /// then the ones the round was started with.
    private var roundSettings: GameSettings { game.phase == .idle ? settings : game.settings }

    /// Mode of the round on the game screen, chosen the same way as `roundSettings`.
    private var roundMode: StimulusMode { game.phase == .idle ? selectedMode : game.mode }

    var gameTitle: String { "\(roundSettings.n)-back · \(roundMode.title)" }
    var eventsPerRound: Int { roundSettings.eventsPerRound }
    var gridSize: Int { roundSettings.gridSize }
    var showsVisualStimuli: Bool { roundMode.usesVisualStimuli }
    var showsAuditoryStimuli: Bool { roundMode.usesAuditoryStimuli }
    var isRoundRunning: Bool { phase == .running }

    var startButtonTitle: String {
        switch phase {
        case .idle: return "Start round"
        case .running: return "Restart round"
        case .finished: return "Play again"
        }
    }

    /// Instruction before a round, nothing during it, and the score after it.
    var roundMessage: String {
        switch phase {
        case .idle: return "Press the match button when the stimulus is the same as \(roundSettings.n) steps back."
        case .running: return " "
        case .finished: return "Round over · Score \(score)"
        }
    }

    // Formatted settings for the home and settings screens
    var modeText: String { selectedMode.title }
    /// Grid size only matters for modes with visual stimuli, letter count only for sound.
    var showsGridSizeSetting: Bool { selectedMode.usesVisualStimuli }
    var showsLetterCountSetting: Bool { selectedMode.usesAuditoryStimuli }
    var nText: String { "\(settings.n)" }
    /// The n the player can choose right now; shorter rounds allow a smaller n.
    var allowedNRange: ClosedRange<Int> { settings.allowedNRange }
    var eventDurationText: String { String(format: "%.1f s", settings.eventDuration) }
    var eventsPerRoundText: String { "\(settings.eventsPerRound)" }
    var gridSizeText: String { "\(settings.gridSize)×\(settings.gridSize)" }
    var letterCountText: String { "\(settings.letterCount)" }
    var spokenLettersText: String { "Letters used: " + settings.spokenLetters.joined(separator: ", ") }

    // Speech fallback
    /// False when the device has no English text-to-speech voice.
    var isSpeechAvailable: Bool { letterVoice != nil }
    /// Shown on the game screen in sound modes when no voice is available.
    var showsSpeechFallback: Bool { showsAuditoryStimuli && !isSpeechAvailable }
    let speechFallbackMessage = "No voice is available on this device, so the letters are shown here instead."

    // IO handling

    private func speak(_ text: String){
        let utterance = AVSpeechUtterance(string: text)
        // Always English, so the letter names sound the same whatever the phone's language is.
        utterance.voice = letterVoice
        synthesizer.stopSpeaking(at: AVSpeechBoundary.immediate )
        synthesizer.speak(utterance)
    }
}
