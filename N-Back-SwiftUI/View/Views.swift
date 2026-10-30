//
//  Views.swift
//  N-Back-SwiftUI
//
//  The View layer (MVVM): every SwiftUI screen and its small helper views.
//  Views only lay out what N_Back_SwiftUIVM publishes and forward taps to it.
//  They hold purely visual state (navigation flags, animations) and no game logic.
//
//  Contents:
//    - ContentView    root navigation stack
//    - HomeView       high score, stimulus choice, current settings, start button
//    - GameView       grid / ear icon, live state, match buttons
//    - SettingsView   persistent settings
//

import SwiftUI

// MARK: - Root

/// Root view: a navigation stack that starts on the home screen.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
    }
}





struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group{
            ForEach(["iPhone SE (3rd generation)", "iPhone 14 Pro Max"], id: \.self) { deviceName in
                           ContentView()
                                .previewDevice(PreviewDevice(rawValue: deviceName))
                                .previewDisplayName(deviceName)
                                .environmentObject(N_Back_SwiftUIVM())
                      }

            ContentView()
                .previewDevice(PreviewDevice(rawValue: "iPhone 14 Pro Max"))
                .previewDisplayName("iPhone 14 Pro Max Landscape")
                .environmentObject(N_Back_SwiftUIVM())
                .previewInterfaceOrientation(.landscapeRight)
        }

    }
}

// MARK: - Home screen

struct HomeView: View {
    @EnvironmentObject var theViewModel : N_Back_SwiftUIVM
    /// Set to true to push the game screen. Navigation lives in the view, not the view model.
    @State private var isShowingGame = false
    /// Compact height means a phone in landscape: there the screen is laid out in two columns.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // Scrolls as a fallback for very small screens and large text sizes.
        ScrollView {
            Group {
                if verticalSizeClass == .compact {
                    HStack(alignment: .top, spacing: 32) {
                        VStack(spacing: 20) {
                            titleAndScore
                            StimulusModePicker(selectedMode: $theViewModel.selectedMode)
                        }
                        VStack(spacing: 20) {
                            CurrentSettingsView()
                            startButton
                        }
                    }
                } else {
                    VStack(spacing: 28) {
                        titleAndScore
                        StimulusModePicker(selectedMode: $theViewModel.selectedMode)
                        CurrentSettingsView()
                        startButton
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationDestination(isPresented: $isShowingGame) {
            GameView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    private var titleAndScore: some View {
        VStack(spacing: 12) {
            Text("N-Back")
                .font(.largeTitle.bold())

            VStack(spacing: 4) {
                Text("High score")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(theViewModel.highScore)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .accessibilityLabel("High score \(theViewModel.highScore)")
            }
        }
    }

    private var startButton: some View {
        Button {
            isShowingGame = true
        } label: {
            Text("START GAME")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: 400)
    }
}

/// Three buttons for choosing visual, auditory or both. The selected one is filled.
struct StimulusModePicker: View {
    @Binding var selectedMode: StimulusMode

    var body: some View {
        HStack(spacing: 12) {
            ForEach(StimulusMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    HStack {
                        Image(systemName: mode.systemImageName)
                            .imageScale(.large)
                        Text(mode.title)
                            // Never break a word over two lines in a narrow column.
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 48)
                    .foregroundColor(selectedMode == mode ? .white : .blue)
                    .background(selectedMode == mode ? Color.blue : Color.blue.opacity(0.12))
                    .cornerRadius(40)
                }
                .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
            }
        }
    }
}

/// Lists the settings the next round will use, with a link to the settings screen.
struct CurrentSettingsView: View {
    @EnvironmentObject var theViewModel : N_Back_SwiftUIVM

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Current settings")
                    .font(.headline)
                Spacer()
                NavigationLink("Change") {
                    SettingsView()
                }
            }
            SettingValueRow(title: "Stimuli", value: theViewModel.modeText)
            SettingValueRow(title: "n", value: theViewModel.nText)
            SettingValueRow(title: "Event duration", value: theViewModel.eventDurationText)
            SettingValueRow(title: "Events per round", value: theViewModel.eventsPerRoundText)
            if theViewModel.showsGridSizeSetting {
                SettingValueRow(title: "Grid size", value: theViewModel.gridSizeText)
            }
            if theViewModel.showsLetterCountSetting {
                SettingValueRow(title: "Spoken letters", value: theViewModel.letterCountText)
            }
        }
        .padding()
        .frame(maxWidth: 400, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView()
        }
        .environmentObject(N_Back_SwiftUIVM())
    }
}

// MARK: - Game screen

struct GameView: View {
    @EnvironmentObject var theViewModel : N_Back_SwiftUIVM

    var body: some View {
        // Wider than tall (phone or tablet in landscape): stimulus on the left, controls on the right.
        // Otherwise everything is stacked, with the stimulus in the middle.
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                HStack(spacing: 24) {
                    stimulus
                    VStack(spacing: 16) {
                        status
                        Spacer(minLength: 0)
                        roundMessageArea
                        controls
                    }
                    .frame(maxWidth: 420)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 20) {
                    status
                    stimulus
                    roundMessageArea
                    controls
                }
                .padding()
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay {
            if theViewModel.showsRoundSummary {
                RoundSummaryView(correctMatches: theViewModel.correctResponses,
                                 missedMatches: theViewModel.missedMatches,
                                 wrongMatches: theViewModel.wrongMatches,
                                 score: theViewModel.score,
                                 isNewHighScore: theViewModel.isNewHighScore) {
                    theViewModel.dismissRoundSummary()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeOut(duration: 0.25), value: theViewModel.showsRoundSummary)
        .navigationTitle(theViewModel.gameTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Leaving mid-round cancels the timer and speech cleanly.
            theViewModel.leaveGame()
        }
    }

    private var status: some View {
        GameStatusView(eventNumber: theViewModel.currentEventNumber,
                       eventsPerRound: theViewModel.eventsPerRound,
                       correctResponses: theViewModel.correctResponses)
    }

    /// The grid for visual modes, or an ear icon for sound only. Takes all the space it is given.
    @ViewBuilder
    private var stimulus: some View {
        VStack(spacing: 12) {
            if theViewModel.showsVisualStimuli {
                StimulusGridView(gridSize: theViewModel.gridSize,
                                 highlightedCell: theViewModel.highlightedCell)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !theViewModel.showsSpeechFallback {
                Image(systemName: "ear")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Listen to the spoken letters")
            }
            if theViewModel.showsSpeechFallback {
                SpeechFallbackView(message: theViewModel.speechFallbackMessage,
                                   letter: theViewModel.displayedLetter)
            }
        }
    }

    private var roundMessageArea: some View {
        roundMessage
            // Fixed height so the grid does not move when the message changes.
            .frame(minHeight: 50)
    }

    /// Match buttons plus the start/restart button.
    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 16) {
            if theViewModel.showsVisualStimuli {
                MatchButton(title: "Position match", systemImageName: "eye",
                            mistakeCount: theViewModel.visualMistakeCount) {
                    theViewModel.registerMatch(for: .visual)
                }
            }
            if theViewModel.showsAuditoryStimuli {
                MatchButton(title: "Sound match", systemImageName: "speaker.wave.3.fill",
                            mistakeCount: theViewModel.auditoryMistakeCount) {
                    theViewModel.registerMatch(for: .auditory)
                }
            }
        }
        .disabled(!theViewModel.isRoundRunning)
        .opacity(theViewModel.isRoundRunning ? 1 : 0.4)

        // Always on screen so the layout does not jump when a round starts.
        Button {
            theViewModel.startRound()
        } label: {
            Text(theViewModel.startButtonTitle)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.bordered)
    }

    /// Styled by phase; the text itself comes from the view model.
    @ViewBuilder
    private var roundMessage: some View {
        let message = Text(theViewModel.roundMessage)
        switch theViewModel.phase {
        case .idle:
            message
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        case .running:
            message
        case .finished:
            message
                .font(.title2.bold())
        }
    }
}

/// Shown instead of speech when the device has no voice: a short message and the current letter.
struct SpeechFallbackView: View {
    let message: String
    let letter: String?

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            // A space keeps the height fixed between events, so the layout does not jump.
            Text(letter ?? " ")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
                .accessibilityLabel(letter.map { "Letter \($0)" } ?? "No letter")
        }
    }
}

/// Shows the current event number and the number of correct responses so far.
struct GameStatusView: View {
    let eventNumber: Int
    let eventsPerRound: Int
    let correctResponses: Int

    var body: some View {
        HStack {
            Label("Event \(eventNumber)/\(eventsPerRound)", systemImage: "number")
            Spacer()
            Label("Correct \(correctResponses)", systemImage: "checkmark.circle")
        }
        .font(.headline.monospacedDigit())
    }
}

/// Popup shown when a round has been played to the end.
/// Closed with the Close button or by tapping anywhere outside the card.
struct RoundSummaryView: View {
    let correctMatches: Int
    let missedMatches: Int
    let wrongMatches: Int
    let score: Int
    let isNewHighScore: Bool
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)

            // Scrolls only if the card does not fit, e.g. a small phone in landscape.
            ViewThatFits(in: .vertical) {
                card
                ScrollView { card }
            }
            .padding()
            .frame(maxWidth: 400)
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            Text("Round over")
                .font(.title2.bold())
            if isNewHighScore {
                Label("New high score!", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }
            VStack(spacing: 10) {
                SummaryRow(title: "Correct matches", value: correctMatches,
                           systemImageName: "checkmark.circle.fill", color: .green)
                SummaryRow(title: "Missed matches", value: missedMatches,
                           systemImageName: "minus.circle.fill", color: .gray)
                SummaryRow(title: "Wrong matches", value: wrongMatches,
                           systemImageName: "xmark.circle.fill", color: .orange)
                Divider()
                SummaryRow(title: "Score", value: score,
                           systemImageName: "trophy.fill", color: .blue)
                    .font(.headline)
            }
            Button(action: onClose) {
                Text("Close")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 20)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }
}

/// One line in the round summary: icon, title and number.
struct SummaryRow: View {
    let title: String
    let value: Int
    let systemImageName: String
    let color: Color

    var body: some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImageName)
                    .foregroundStyle(color)
            }
            Spacer()
            Text("\(value)")
                .monospacedDigit()
                .bold()
        }
    }
}

/// A square grid of gridSize × gridSize cells with one cell lit up.
struct StimulusGridView: View {
    let gridSize: Int
    let highlightedCell: Int?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<gridSize, id: \.self) { column in
                        let cell = row * gridSize + column
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cell == highlightedCell ? Color.blue : Color(.systemGray5))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: highlightedCell)
        // Keeps the grid square on every screen size and orientation.
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(highlightedCell.map { "Cell \($0 + 1) is lit" } ?? "No cell lit")
    }
}

/// A large match button. When `mistakeCount` goes up it gently shakes and turns orange for a moment.
struct MatchButton: View {
    let title: String
    let systemImageName: String
    let mistakeCount: Int
    let action: () -> Void

    @State private var shakeAmount: CGFloat = 0
    @State private var isShowingMistake = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImageName)
                    .imageScale(.large)
                Text(title)
                    .font(.headline)
            }
            // Well above the 44 pt minimum touch target.
            .frame(maxWidth: .infinity, minHeight: 72)
            .foregroundColor(.white)
            .background(isShowingMistake ? Color.orange : Color.blue)
            .cornerRadius(20)
        }
        .modifier(ShakeEffect(animatableData: shakeAmount))
        .onChange(of: mistakeCount) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                shakeAmount += 1
                isShowingMistake = true
            }
            // Fade the colour back after the shake. A delayed withAnimation here would cancel the change above.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isShowingMistake = false
                }
            }
        }
    }
}

/// Moves the view side to side a few times; one full shake per unit of animatableData.
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = 8 * sin(animatableData * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            GameView()
        }
        .environmentObject(N_Back_SwiftUIVM())
    }
}

// MARK: - Settings screen

struct SettingsView: View {
    @EnvironmentObject var theViewModel : N_Back_SwiftUIVM

    /// Reads from and writes to the view model, which validates and saves each change.
    private var settings: Binding<GameSettings> {
        Binding(get: { theViewModel.settings },
                set: { theViewModel.updateSettings($0) })
    }

    var body: some View {
        Form {
            Section {
                Stepper(value: settings.n, in: theViewModel.allowedNRange) {
                    SettingValueRow(title: "n (steps back)", value: theViewModel.nText)
                }
            } footer: {
                Text("Press match when the stimulus is the same as n steps earlier. Longer rounds allow a larger n.")
            }

            Section("Round") {
                Stepper(value: settings.eventsPerRound, in: GameSettings.allowedEventsPerRoundRange, step: 5) {
                    SettingValueRow(title: "Events per round", value: theViewModel.eventsPerRoundText)
                }
                Stepper(value: settings.eventDuration,
                        in: GameSettings.allowedEventDurationRange,
                        step: GameSettings.eventDurationStep) {
                    SettingValueRow(title: "Event duration", value: theViewModel.eventDurationText)
                }
            }

            Section {
                Stepper(value: settings.gridSize, in: GameSettings.allowedGridSizeRange) {
                    SettingValueRow(title: "Grid size", value: theViewModel.gridSizeText)
                }
            } header: {
                Text("Visual")
            }

            Section {
                Stepper(value: settings.letterCount, in: GameSettings.allowedLetterCountRange) {
                    SettingValueRow(title: "Spoken letters", value: theViewModel.letterCountText)
                }
            } header: {
                Text("Auditory")
            } footer: {
                Text(theViewModel.spokenLettersText)
            }

            Section {
                Button("Reset to defaults", role: .destructive) {
                    theViewModel.resetSettings()
                }
            }
        }
        .navigationTitle("Settings")
    }
}

/// A setting's name on the left and its current value on the right.
struct SettingValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
        }
        .environmentObject(N_Back_SwiftUIVM())
    }
}
