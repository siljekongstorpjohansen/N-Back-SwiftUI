//
//  N_Back_SwiftUITests.swift
//  N-Back-SwiftUITests
//
//  Unit tests for the Model layer (no UI): sequence generation, match-rate enforcement,
//  the first-n guarantee, press rules (before start, after end, first n events, double press),
//  scoring, and settings validation/storage. Run with ⌘U in Xcode.
//

import XCTest
@testable import N_Back_SwiftUI

// MARK: - Sequence generation

final class NBackSequenceGeneratorTests: XCTestCase {

    /// Every combination of settings the settings screen allows (n is limited by validated()).
    private var allAllowedSettings: [GameSettings] {
        var result: [GameSettings] = []
        for events in stride(from: GameSettings.allowedEventsPerRoundRange.lowerBound,
                             through: GameSettings.allowedEventsPerRoundRange.upperBound, by: 5) {
            for n in 1...GameSettings.maxN {
                var settings = GameSettings()
                settings.eventsPerRound = events
                settings.n = n
                result.append(settings.validated())
            }
        }
        return result
    }

    private func matchCount(in sequence: [Int], n: Int) -> Int {
        (0..<sequence.count).filter { NBackSequenceGenerator.isMatch(in: sequence, at: $0, n: n) }.count
    }

    func testSequenceHasRequestedLengthAndValuesInRange() {
        for combinations in [2, 8, 9, 25] {
            let sequence = NBackSequenceGenerator.generate(length: 30, n: 2, combinations: combinations, matchRate: 0.3)
            XCTAssertEqual(sequence.count, 30)
            XCTAssertTrue(sequence.allSatisfy { (0..<combinations).contains($0) },
                          "values must be indexes 0..<\(combinations)")
        }
    }

    func testEmptyRoundGivesEmptySequence() {
        XCTAssertEqual(NBackSequenceGenerator.generate(length: 0, n: 2, combinations: 9, matchRate: 0.3), [])
    }

    func testMatchRateIsBetween20And40Percent() {
        for settings in allAllowedSettings {
            for combinations in [2, 8, 9, 25] {
                for _ in 0..<10 {
                    let sequence = NBackSequenceGenerator.generate(length: settings.eventsPerRound, n: settings.n,
                                                                   combinations: combinations,
                                                                   matchRate: settings.matchRate)
                    let eligible = settings.eventsPerRound - settings.n
                    let rate = Double(matchCount(in: sequence, n: settings.n)) / Double(eligible)
                    XCTAssertGreaterThanOrEqual(rate, 0.2, "events \(settings.eventsPerRound), n \(settings.n)")
                    XCTAssertLessThanOrEqual(rate, 0.4, "events \(settings.eventsPerRound), n \(settings.n)")
                }
            }
        }
    }

    func testFirstNEventsAreNeverMatches() {
        for settings in allAllowedSettings {
            let sequence = NBackSequenceGenerator.generate(length: settings.eventsPerRound, n: settings.n,
                                                           combinations: 9, matchRate: settings.matchRate)
            for index in 0..<settings.n {
                XCTAssertFalse(NBackSequenceGenerator.isMatch(in: sequence, at: index, n: settings.n),
                               "event \(index) is within the first n = \(settings.n)")
            }
        }
    }

    func testIsMatchComparesWithTheEventNStepsBack() {
        let sequence = [4, 7, 4, 1, 7]
        XCTAssertFalse(NBackSequenceGenerator.isMatch(in: sequence, at: 1, n: 2), "index < n")
        XCTAssertTrue(NBackSequenceGenerator.isMatch(in: sequence, at: 2, n: 2), "4 == 4")
        XCTAssertFalse(NBackSequenceGenerator.isMatch(in: sequence, at: 3, n: 2), "1 != 7")
        XCTAssertFalse(NBackSequenceGenerator.isMatch(in: sequence, at: 9, n: 2), "out of range")
    }

    func testAllowedMatchCountStaysWithin20To40Percent() {
        for eligible in GameSettings.minEligibleEvents...60 {
            let range = NBackSequenceGenerator.allowedMatchCount(eligibleCount: eligible)
            XCTAssertGreaterThanOrEqual(Double(range.lowerBound) / Double(eligible), 0.2)
            XCTAssertLessThanOrEqual(Double(range.upperBound) / Double(eligible), 0.4)
        }
    }
}

// MARK: - Round state machine and press rules

final class NBackGameTests: XCTestCase {

    private var settings: GameSettings {
        var settings = GameSettings()
        settings.n = 2
        settings.eventsPerRound = 20
        return settings
    }

    /// Starts a visual round and moves to the event with the given index.
    private func game(atEvent index: Int, mode: StimulusMode = .visual) -> NBackGame {
        var game = NBackGame()
        game.start(settings: settings, mode: mode)
        for _ in 0...index { game.advanceToNextEvent() }
        return game
    }

    /// First event index (after the first n) that is or is not a match in the visual sequence.
    private func firstEvent(isMatch: Bool, in game: NBackGame) -> Int {
        let index = (settings.n..<settings.eventsPerRound).first {
            NBackSequenceGenerator.isMatch(in: game.visualSequence, at: $0, n: settings.n) == isMatch
        }
        return index!
    }

    func testStartsIdleAndRunsAfterStart() {
        var game = NBackGame()
        XCTAssertEqual(game.phase, .idle)
        game.start(settings: settings, mode: .visual)
        XCTAssertEqual(game.phase, .running)
        XCTAssertEqual(game.currentEventNumber, 0)
    }

    func testPressBeforeRoundStartsIsIgnored() {
        var game = NBackGame()
        XCTAssertEqual(game.registerMatch(for: .visual), .ignored)
        XCTAssertEqual(game.hits + game.falseAlarms, 0)
    }

    func testPressDuringFirstNEventsIsIgnored() {
        for index in 0..<settings.n {
            var game = game(atEvent: index)
            XCTAssertEqual(game.registerMatch(for: .visual), .ignored, "event \(index)")
            XCTAssertEqual(game.hits + game.falseAlarms, 0)
        }
    }

    func testSecondPressOnSameEventIsIgnored() {
        var game = game(atEvent: settings.n)
        let first = game.registerMatch(for: .visual)
        XCTAssertNotEqual(first, .ignored)
        XCTAssertEqual(game.registerMatch(for: .visual), .ignored)
        XCTAssertEqual(game.registerMatch(for: .visual), .ignored)
        XCTAssertEqual(game.hits + game.falseAlarms, 1, "only the first press counts")
    }

    func testPressIsAllowedAgainOnTheNextEvent() {
        var game = game(atEvent: settings.n)
        _ = game.registerMatch(for: .visual)
        game.advanceToNextEvent()
        XCTAssertNotEqual(game.registerMatch(for: .visual), .ignored)
    }

    func testPressAfterRoundEndsIsIgnored() {
        var game = game(atEvent: settings.n)
        while game.phase == .running { game.advanceToNextEvent() }
        XCTAssertEqual(game.phase, .finished)
        let before = game.hits + game.falseAlarms
        XCTAssertEqual(game.registerMatch(for: .visual), .ignored)
        XCTAssertEqual(game.hits + game.falseAlarms, before)
    }

    func testPressAfterLeavingMidRoundIsIgnored() {
        var game = game(atEvent: settings.n + 1)
        game.stop()
        XCTAssertEqual(game.phase, .finished)
        XCTAssertEqual(game.registerMatch(for: .visual), .ignored)
    }

    func testPressForStreamNotInUseIsIgnored() {
        var game = game(atEvent: settings.n, mode: .visual)
        XCTAssertEqual(game.registerMatch(for: .auditory), .ignored)
    }

    func testDualModeAllowsOnePressPerStream() {
        var game = game(atEvent: settings.n, mode: .dual)
        XCTAssertNotEqual(game.registerMatch(for: .visual), .ignored)
        XCTAssertNotEqual(game.registerMatch(for: .auditory), .ignored)
        XCTAssertEqual(game.registerMatch(for: .visual), .ignored)
        XCTAssertEqual(game.registerMatch(for: .auditory), .ignored)
    }

    func testRoundFinishesAfterTheLastEvent() {
        var game = NBackGame()
        game.start(settings: settings, mode: .visual)
        for _ in 0..<settings.eventsPerRound { game.advanceToNextEvent() }
        XCTAssertEqual(game.phase, .running)
        XCTAssertEqual(game.currentEventNumber, settings.eventsPerRound)
        game.advanceToNextEvent()
        XCTAssertEqual(game.phase, .finished)
    }

    // MARK: Scoring

    func testPressOnMatchIsAHit() {
        var game = NBackGame()
        game.start(settings: settings, mode: .visual)
        let index = firstEvent(isMatch: true, in: game)
        for _ in 0...index { game.advanceToNextEvent() }
        XCTAssertEqual(game.registerMatch(for: .visual), .correct)
        XCTAssertEqual(game.hits, 1)
        XCTAssertEqual(game.falseAlarms, 0)
    }

    func testPressOnNonMatchIsAFalseAlarm() {
        var game = NBackGame()
        game.start(settings: settings, mode: .visual)
        let index = firstEvent(isMatch: false, in: game)
        for _ in 0...index { game.advanceToNextEvent() }
        XCTAssertEqual(game.registerMatch(for: .visual), .incorrect)
        XCTAssertEqual(game.falseAlarms, 1)
        XCTAssertEqual(game.hits, 0)
    }

    func testUnpressedMatchIsCountedAsMissOnTheNextTick() {
        var game = NBackGame()
        game.start(settings: settings, mode: .visual)
        let index = firstEvent(isMatch: true, in: game)
        for _ in 0...index { game.advanceToNextEvent() }
        XCTAssertEqual(game.misses, 0)
        game.advanceToNextEvent()
        XCTAssertEqual(game.misses, 1)
    }

    func testScoreIsHitsMinusFalseAlarmsAndNeverNegative() {
        var game = NBackGame()
        game.start(settings: settings, mode: .visual)
        // Press on every event: all matches become hits, all non-matches false alarms.
        var hits = 0, falseAlarms = 0
        for _ in 0..<settings.eventsPerRound {
            game.advanceToNextEvent()
            switch game.registerMatch(for: .visual) {
            case .correct: hits += 1
            case .incorrect: falseAlarms += 1
            case .ignored: break
            }
        }
        XCTAssertEqual(game.hits, hits)
        XCTAssertEqual(game.falseAlarms, falseAlarms)
        XCTAssertGreaterThan(falseAlarms, hits, "with 20–40 % matches there are more non-matches")
        XCTAssertEqual(game.score, 0, "score is max(0, hits − false alarms), never negative")
    }

    func testScoreCountsHitsWhenThereAreNoFalseAlarms() {
        var game = NBackGame()
        game.start(settings: settings, mode: .visual)
        // Press only on matches.
        for index in 0..<settings.eventsPerRound {
            game.advanceToNextEvent()
            if NBackSequenceGenerator.isMatch(in: game.visualSequence, at: index, n: settings.n) {
                _ = game.registerMatch(for: .visual)
            }
        }
        let matches = (0..<settings.eventsPerRound).filter {
            NBackSequenceGenerator.isMatch(in: game.visualSequence, at: $0, n: settings.n)
        }.count
        XCTAssertEqual(game.score, matches)
        XCTAssertEqual(game.falseAlarms, 0)
    }
}

// MARK: - Settings

final class GameSettingsTests: XCTestCase {

    func testNIsLimitedSoThreeEventsCanBeMatches() {
        var settings = GameSettings()
        settings.eventsPerRound = 10
        settings.n = 9
        XCTAssertEqual(settings.validated().n, 7)
        settings.eventsPerRound = 12
        XCTAssertEqual(settings.validated().n, 9)
    }

    func testValidatedClampsEveryValue() {
        var settings = GameSettings()
        settings.eventsPerRound = 1_000
        settings.eventDuration = 0
        settings.gridSize = 99
        settings.letterCount = 0
        settings.n = 0
        let valid = settings.validated()
        XCTAssertEqual(valid.eventsPerRound, GameSettings.allowedEventsPerRoundRange.upperBound)
        XCTAssertEqual(valid.eventDuration, GameSettings.allowedEventDurationRange.lowerBound)
        XCTAssertEqual(valid.gridSize, GameSettings.allowedGridSizeRange.upperBound)
        XCTAssertEqual(valid.letterCount, GameSettings.allowedLetterCountRange.lowerBound)
        XCTAssertEqual(valid.n, 1)
    }

    func testSpokenLettersAreDistinctAndEachHasAName() {
        let letters = GameSettings.allSpokenLetters
        XCTAssertEqual(Set(letters).count, letters.count)
        for letter in letters {
            XCTAssertNotNil(GameSettings.letterNames[letter], "\(letter) needs a spoken name")
        }
    }

    func testSettingsStoreSavesAndLoads() throws {
        let suiteName = "N_Back_SwiftUITests.settings"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = GameSettingsStore(defaults: defaults)
        var settings = GameSettings()
        settings.n = 4
        settings.eventsPerRound = 30
        settings.eventDuration = 1.5
        settings.gridSize = 5
        settings.letterCount = 6
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func testHighScoreStoreKeepsTheBestScore() throws {
        let suiteName = "N_Back_SwiftUITests.highScore"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = HighScoreStore(defaults: defaults)
        XCTAssertEqual(store.saveIfHigher(5), 5)
        XCTAssertEqual(store.saveIfHigher(3), 5, "a lower score does not replace the high score")
        XCTAssertEqual(store.load(), 5)
    }
}
