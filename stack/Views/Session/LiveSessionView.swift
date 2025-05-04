import SwiftUI
import FirebaseFirestore

struct LiveSessionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.presentationMode) var presentationMode
    let userId: String
    @ObservedObject var sessionStore: SessionStore
    private let db = Firestore.firestore()
    
    // Form Data
    @State private var selectedGame: GameOption?
    @State private var buyIn = ""
    @State private var cashout = ""
    @State private var isLoading = false
    @State private var showingAddGame = false
    @State private var showingRebuyAlert = false
    @State private var rebuyAmount = ""
    @State private var showingExitAlert = false
    @State private var showingCashoutPrompt = false
    @State private var sessionMode: SessionMode = .setup
    
    enum SessionMode {
        case setup     // Initial game selection and buy-in
        case active    // Session is running
        case paused    // Session is paused
        case ending    // Session has ended, entering cashout
    }
    
    @StateObject private var gameService: CustomGameService
    
    init(userId: String, sessionStore: SessionStore) {
        self.userId = userId
        self.sessionStore = sessionStore
        _gameService = StateObject(wrappedValue: CustomGameService(userId: userId))
    }
    
    private var formattedElapsedTime: (hours: Int, minutes: Int, seconds: Int) {
        let totalSeconds = Int(sessionStore.liveSession.elapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return (hours, minutes, seconds)
    }
    
    private var formattedHours: String {
        let hours = sessionStore.liveSession.elapsedTime / 3600
        return String(format: "%.1f", hours)
    }
    
    var setupSectionView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section title with icon
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.1), Color.green.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                }
                Text("Select Game")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                Spacer()
                Button(action: { showingAddGame = true }) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 40, height: 40)
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                    }
                    .shadow(color: Color.green.opacity(0.3), radius: 8, y: 2)
                }
            }
            .padding(.horizontal, 18)
            
            if gameService.customGames.isEmpty {
                // Beautiful empty state
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 80, height: 80)
                        Image(systemName: "plus.circle")
                            .font(.system(size: 36))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    
                    Text("No Games Added Yet")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Tap + to add your first poker game")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.03))
                        .background(BlurView(style: .systemThinMaterialDark))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
                .padding(.horizontal, 18)
                .padding(.top, 10)
            } else {
                // Game selection grid with beautiful scrolling
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(gameService.customGames) { game in
                            GameOptionCards(
                                game: GameOption(name: game.name, stakes: game.stakes),
                                isSelected: selectedGame?.name == game.name && selectedGame?.stakes == game.stakes,
                                action: { selectedGame = GameOption(name: game.name, stakes: game.stakes) }
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                }
            }
            
            // Buy-in section with modern design
            VStack(alignment: .leading, spacing: 20) {
                // Section title with icon
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.1), Color.green.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 36, height: 36)
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                    }
                    Text("Buy In")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                }
                .padding(.horizontal, 18)
                
                // Beautiful buy-in field
                HStack {
                    Text("$")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.8))
                        .padding(.leading, 24)
                    
                    TextField("0", text: $buyIn)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(height: 70)
                    
                    if !buyIn.isEmpty {
                        Button(action: { buyIn = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing, 20)
                        .transition(.opacity)
                        .animation(.easeInOut, value: buyIn.isEmpty)
                    }
                }
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.08), Color.green.opacity(0.06)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .background(BlurView(style: .systemThinMaterialDark))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                .padding(.horizontal, 18)
            }
            Spacer()
        }
        .padding(.top, 18)
    }
    
    var timerSectionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session Timer")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.leading, 2)
            HStack(spacing: 18) {
                TimerUnitView(
                    value: formattedElapsedTime.hours,
                    unit: "HR"
                )
                TimerUnitView(
                    value: formattedElapsedTime.minutes,
                    unit: "MIN"
                )
                TimerUnitView(
                    value: formattedElapsedTime.seconds,
                    unit: "SEC"
                )
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.08), Color.green.opacity(0.08)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .background(BlurView(style: .systemThinMaterialDark))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.green.opacity(0.18), lineWidth: 1.5)
            )
            .shadow(color: Color.green.opacity(0.10), radius: 8, y: 2)
        }
        .padding(.horizontal, 18)
    }

    var cashoutSectionView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section title with icon
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.1), Color.green.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                }
                Text("Cashout")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
            }
            .padding(.horizontal, 18)
            // Beautiful cashout field
            HStack {
                Text("$")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.8))
                    .padding(.leading, 24)
                TextField("0", text: $cashout)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(height: 70)
                if !cashout.isEmpty {
                    Button(action: { cashout = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 20)
                    .transition(.opacity)
                    .animation(.easeInOut, value: cashout.isEmpty)
                }
            }
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.08), Color.green.opacity(0.06)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .background(BlurView(style: .systemThinMaterialDark))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
            .padding(.horizontal, 18)
        }
    }

    var scrollContentView: some View {
        VStack(spacing: 32) {
            // Game selection section (only in setup mode)
            if sessionMode == .setup {
                setupSectionView
            }
            // Timer section (if not in setup mode)
            if sessionMode != .setup {
                timerSectionView
            }
            // Cashout section (only in ending mode)
            if sessionMode == .ending {
                cashoutSectionView
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 32)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackgroundView()
                // Main content based on session mode
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if sessionMode == .active || sessionMode == .paused {
                        ActiveSessionView(
                            elapsedTime: formattedElapsedTime,
                            buyIn: .constant(String(format: "%.2f", sessionStore.liveSession.buyIn)),
                            gameName: sessionStore.liveSession.gameName,
                            gameStakes: sessionStore.liveSession.stakes,
                            isPaused: sessionMode == .paused,
                            onPause: pauseSession,
                            onResume: resumeSession,
                            onRebuy: { showingRebuyAlert = true },
                            onEnd: { showingCashoutPrompt = true }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // Setup or cashout view
                        ScrollView(showsIndicators: false) {
                            scrollContentView
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                }
                // Bottom buttons
                VStack {
                    Spacer()
                    
                    switch sessionMode {
                    case .setup:
                        // Start button
                        Button(action: startSession) {
                            Text("Start Session")
                                .font(.system(size: 17, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                                .foregroundColor(.black)
                                .cornerRadius(27)
                        }
                        .disabled(selectedGame == nil || buyIn.isEmpty)
                        .opacity((selectedGame == nil || buyIn.isEmpty) ? 0.6 : 1)
                        .padding(.horizontal)
                        .padding(.bottom, 34)
                        
                    case .active:
                        // No bottom buttons in active mode (they're in the ActiveSessionView)
                        EmptyView()
                        
                    case .paused:
                        // No bottom buttons in paused mode (they're in the ActiveSessionView)
                        EmptyView()
                        
                    case .ending:
                        Button(action: saveSession) {
                            HStack {
                                Text("Save Session")
                                    .font(.system(size: 17, weight: .bold))
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .padding(.leading, 8)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                            .foregroundColor(.black)
                            .cornerRadius(27)
                        }
                        .disabled(cashout.isEmpty)
                        .opacity(cashout.isEmpty ? 0.6 : 1)
                        .padding(.horizontal)
                        .padding(.bottom, 34)
                    }
                }
            }
            .navigationTitle(sessionMode == .active ? "Live Session" : (sessionMode == .ending ? "End Session" : "New Session"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { 
                        if sessionMode == .active {
                            showingExitAlert = true
                        } else if sessionMode == .ending {
                            // Go back to active session
                            withAnimation {
                                sessionMode = .active
                                sessionStore.resumeLiveSession()
                            }
                        } else {
                            dismiss() 
                        }
                    }) {
                        Image(systemName: sessionMode == .ending ? "chevron.left" : "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                if sessionMode == .active {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Minimize") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .alert("End Session?", isPresented: $showingExitAlert) {
                Button("Cancel", role: .cancel) { }
                Button("End Without Saving", role: .destructive) {
                    sessionStore.clearLiveSession()
                    dismiss()
                }
            } message: {
                Text("Your live session is still running. Do you want to end it without saving?")
            }
            .alert("Add Rebuy", isPresented: $showingRebuyAlert) {
                TextField("Amount", text: $rebuyAmount)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) { 
                    rebuyAmount = ""
                }
                Button("Add") {
                    addRebuy()
                }
            } message: {
                Text("Enter rebuy amount")
            }
            .alert("End Session", isPresented: $showingCashoutPrompt) {
                Button("Cancel", role: .cancel) {
                    // Stay in active mode
                }
                Button("End Session", role: .destructive) {
                    endSession()
                }
            } message: {
                Text("Do you want to end your session and enter your cashout amount?")
            }
            .sheet(isPresented: $showingAddGame) {
                AddCustomGameView(gameService: gameService)
            }
            .onAppear {
                // Check if there's a live session already running
                if sessionStore.liveSession.isActive || sessionStore.showLiveSessionBar {
                    sessionMode = sessionStore.liveSession.isActive ? .active : .paused
                }
            }
            .onChange(of: sessionStore.liveSession.isActive) { isActive in
                withAnimation {
                    sessionMode = isActive ? .active : .paused
                }
            }
            .onDisappear {
                // Safety check: If we're in ending mode and the view disappears without saving,
                // we should clear the session state to prevent it from reappearing
                if sessionMode == .ending {
                    sessionStore.clearLiveSession()
                }
            }
        }
        .interactiveDismissDisabled(sessionMode == .active)
    }
    
    private func startSession() {
        guard let game = selectedGame, let buyInValue = Double(buyIn) else { return }
        
        // Start session in session store
        sessionStore.startLiveSession(
            gameName: game.name,
            stakes: game.stakes,
            buyIn: buyInValue
        )
        
        // Update local UI
        withAnimation {
            sessionMode = .active
        }
    }
    
    private func pauseSession() {
        sessionStore.pauseLiveSession()
        withAnimation { sessionMode = .paused }
    }
    
    private func resumeSession() {
        sessionStore.resumeLiveSession()
        withAnimation { sessionMode = .active }
    }
    
    private func endSession() {
        // Go directly to cashout mode, do not pause first
        sessionStore.stopLiveSessionTimer() // Stop timer, but do not pause (so isActive stays true until save)
        withAnimation {
            sessionMode = .ending
        }
    }
    
    private func addRebuy() {
        // Get the rebuy amount from the input field
        if let rebuyValue = Double(rebuyAmount), rebuyValue > 0 {
            // Update the session store with the new buy-in
            sessionStore.updateLiveSessionBuyIn(amount: rebuyValue)
        }
        
        // Reset the rebuy amount field
        rebuyAmount = ""
    }
    
    private func saveSession() {
        guard let cashoutValue = Double(cashout) else { return }
        isLoading = true
        
        // Store important session data locally before clearing
        let gameName = sessionStore.liveSession.gameName
        let stakes = sessionStore.liveSession.stakes
        let buyIn = sessionStore.liveSession.buyIn
        let startTime = sessionStore.liveSession.startTime
        let elapsedTime = sessionStore.liveSession.elapsedTime
        
        // Clear session state immediately to prevent race conditions
        sessionStore.clearLiveSession()
        
        // Create session data with the stored values
        let sessionData: [String: Any] = [
            "userId": userId,
            "gameType": "CASH GAME",
            "gameName": gameName,
            "stakes": stakes,
            "startDate": Timestamp(date: startTime),
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: Date()),
            "hoursPlayed": elapsedTime / 3600,
            "buyIn": buyIn,
            "cashout": cashoutValue,
            "profit": cashoutValue - buyIn,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        // Save the session with our local data
        db.collection("sessions").addDocument(data: sessionData) { error in
            DispatchQueue.main.async {
                self.isLoading = false
                if error == nil {
                    // Session saved successfully
                    dismiss()
                } else {
                    // In a real app, you'd want to handle the error
                    print("Error saving session: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
}

// Modernize ActiveSessionView
struct ActiveSessionView: View {
    let elapsedTime: (hours: Int, minutes: Int, seconds: Int)
    @Binding var buyIn: String
    let gameName: String
    let gameStakes: String
    let isPaused: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onRebuy: () -> Void
    let onEnd: () -> Void
    var body: some View {
        VStack(spacing: 32) {
            // Modern glassy card for game info
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(gameStakes)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    Text(gameName)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.green.opacity(0.7))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Buy-in")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                    Text("$\(buyIn)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                        .shadow(color: Color.green.opacity(0.18), radius: 2, y: 1)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.10), Color.green.opacity(0.10)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .background(BlurView(style: .systemThinMaterialDark))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.green.opacity(0.18), lineWidth: 1.5)
            )
            .shadow(color: Color.green.opacity(0.10), radius: 10, y: 2)
            // Timer display with glowing border
            VStack(spacing: 10) {
                Text("Session Duration")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    Text("\(elapsedTime.hours)")
                        .font(.system(size: 68, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(minWidth: 90, alignment: .center)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    Text(":")
                        .font(.system(size: 68, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .offset(y: -4)
                    Text(String(format: "%02d", elapsedTime.minutes))
                        .font(.system(size: 68, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(minWidth: 90, alignment: .center)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    Text(":")
                        .font(.system(size: 68, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .offset(y: -4)
                    Text(String(format: "%02d", elapsedTime.seconds))
                        .font(.system(size: 68, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(minWidth: 90, alignment: .center)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.green.opacity(0.10), Color.white.opacity(0.10)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .background(BlurView(style: .systemThinMaterialDark))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.green.opacity(0.22), lineWidth: 2)
                        .shadow(color: Color.green.opacity(0.18), radius: 8, y: 2)
                )
                .shadow(color: Color.green.opacity(0.10), radius: 10, y: 2)
            }
            // Action buttons
            HStack(spacing: 18) {
                // Rebuy button
                Button(action: onRebuy) {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                        Text("Rebuy")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.blue.opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.blue.opacity(0.28), lineWidth: 1.2)
                    )
                    .shadow(color: Color.blue.opacity(0.10), radius: 6, y: 2)
                }
                // Pause/Resume button
                Button(action: { isPaused ? onResume() : onPause() }) {
                    VStack(spacing: 8) {
                        Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 30))
                        Text(isPaused ? "Resume" : "Pause")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isPaused ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isPaused ? Color.green.opacity(0.28) : Color.orange.opacity(0.28), lineWidth: 1.2)
                    )
                    .shadow(color: isPaused ? Color.green.opacity(0.10) : Color.orange.opacity(0.10), radius: 6, y: 2)
                }
                // End button
                Button(action: onEnd) {
                    VStack(spacing: 8) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 30))
                        Text("End")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.red.opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.red.opacity(0.28), lineWidth: 1.2)
                    )
                    .shadow(color: Color.red.opacity(0.10), radius: 6, y: 2)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white.opacity(0.03))
                .shadow(color: .black.opacity(0.10), radius: 18, y: 4)
        )
        .padding(.horizontal, 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isPaused)
    }
}

struct TimerUnitView: View {
    let value: Int
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(minWidth: 70)
            
            Text(unit)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.gray)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
        )
    }
}

// Add BlurView helper for glassy backgrounds

// Update GameOptionCard to be more beautiful with the same style as ActiveSessionView
struct GameOptionCards: View {
    let game: GameOption
    let isSelected: Bool
    let action: () -> Void
    
    private var accentColor: Color {
        Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0))
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(game.stakes)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                Text(game.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? accentColor.opacity(0.9) : .gray)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 22)
            .frame(height: 90)
            .frame(minWidth: 130)
            .background(
                ZStack {
                    // Glassy background
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(isSelected ? 0.15 : 0.08),
                                isSelected ? accentColor.opacity(0.15) : Color.white.opacity(0.06)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .background(BlurView(style: .systemThinMaterialDark))
                        
                    // Selection indicator
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(accentColor.opacity(0.6), lineWidth: 2)
                            .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 0)
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                }
            )
            .shadow(color: isSelected ? accentColor.opacity(0.2) : Color.black.opacity(0.1), radius: 8, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

