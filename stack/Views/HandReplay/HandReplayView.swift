import SwiftUI
import Foundation

struct Card: Identifiable {
    let id = UUID()
    let rank: String
    let suit: String
    
    var description: String {
        return rank + suit
    }
    
    // Parse a card string like "Ah" or "Td"
    init(from string: String) {
        self.rank = String(string.prefix(1))
        self.suit = String(string.suffix(1))
    }
}

struct HandReplayView: View {
    let hand: ParsedHandHistory
    @Environment(\.dismiss) var dismiss
    @State private var currentStreetIndex = 0 
    @State private var currentActionIndex = 0
    @State private var isPlaying = false
    @State private var potAmount: Double = 0
    @State private var playerStacks: [String: Double] = [:]
    @State private var foldedPlayers: Set<String> = []
    @State private var isHandComplete = false
    @State private var playerBets: [String: Double] = [:]
    @State private var showdownRevealed = false
    @State private var winningPlayers: Set<String> = []
    @State private var showPotDistribution = false
    @State private var lastCheckPlayer: String? = nil
    @State private var showCheckAnimation: Bool = false
    @State private var showingShareSheet = false
    @State private var showingShareAlert = false
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var userService: UserService
    
    private let tableColor = Color(red: 45/255, green: 120/255, blue: 65/255)
    private let tableBorderColor = Color(red: 74/255, green: 54/255, blue: 38/255)
    
    private var hasMoreActions: Bool {
        guard currentStreetIndex < hand.raw.streets.count else { return false }
        let currentStreet = hand.raw.streets[currentStreetIndex]
        return currentActionIndex < currentStreet.actions.count || currentStreetIndex + 1 < hand.raw.streets.count
    }
    
    // This is the key change - accumulate all cards as the hand progresses
    private var allCommunityCards: [String] {
        var cards: [String] = []
        for i in 0...min(currentStreetIndex, hand.raw.streets.count - 1) {
            cards.append(contentsOf: hand.raw.streets[i].cards)
        }
        return cards
    }
    
    private var isShowdown: Bool {
        guard currentStreetIndex == hand.raw.streets.count - 1 else { return false }
        let currentStreet = hand.raw.streets[currentStreetIndex]
        return currentActionIndex >= currentStreet.actions.count
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Apply new background view
                AppBackgroundView()
                
                VStack(spacing: 0) {
                    // Back and share buttons at the top
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.clear)
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)
                        Spacer()
                        Button(action: { showingShareAlert = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.clear)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 24)
                    
                    Spacer()
                    
                    // Poker Table
                    ZStack {
                        // Table background
                        Ellipse()
                            .fill(tableColor)
                            .overlay(
                                Ellipse()
                                    .stroke(tableBorderColor, lineWidth: 8)
                            )
                            .frame(width: geometry.size.width * 0.93, height: geometry.size.height * 0.75)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.4)
                            .shadow(color: .black.opacity(0.5), radius: 10)
                        
                        // Stack Logo - moved up
                        Text("STACK")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(0.3)
                            .offset(y: -geometry.size.height * 0.28)

                        // Pot display - centered
                        if potAmount > 0 {
                            VStack(spacing: 4) {
                                Text("Pot")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                                ChipView(amount: potAmount)
                            }
                            .offset(y: -geometry.size.height * 0.2)
                        }

                        // Community Cards - centered, a bit below the pot
                        CommunityCardsView(cards: allCommunityCards)
                            .offset(y: -geometry.size.height * 0.08)

                        // Player Seats
                        ForEach(hand.raw.players, id: \.seat) { player in
                            PlayerSeatView(
                                player: player,
                                isFolded: foldedPlayers.contains(player.name),
                                isHero: player.isHero,
                                stack: playerStacks[player.name] ?? player.stack,
                                geometry: geometry,
                                allPlayers: hand.raw.players,
                                betAmount: playerBets[player.name],
                                showdownRevealed: showdownRevealed,
                                isWinner: winningPlayers.contains(player.name),
                                showPotDistribution: showPotDistribution,
                                showCheck: showCheckAnimation && lastCheckPlayer == player.name
                            )
                        }
                    }
                    .frame(height: geometry.size.height * 0.75)
                    
                    Spacer()
                        .frame(height: 0) // Collapse this spacer
                    
                    // Controls at the bottom
                    HStack(spacing: 20) {
                        Button(action: startReplay) {
                            Text(isPlaying ? "Reset" : "Start")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 100, height: 36)
                                .background(Color(red: 123/255, green: 255/255, blue: 99/255))
                                .cornerRadius(18)
                        }
                        
                        Button(action: nextAction) {
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 100, height: 36)
                                .background(Color(red: 123/255, green: 255/255, blue: 99/255))
                                .opacity(isPlaying && hasMoreActions ? 1 : 0.5)
                                .cornerRadius(18)
                        }
                        .disabled(!isPlaying || !hasMoreActions)
                    }
                    .padding(.vertical, 38)
                    .frame(maxWidth: .infinity)
                    .background(
                        Color.black.opacity(0)
                    )
                }
            }
        }
        .onAppear {
            initializeStacks()
        }
        .alert("Share Hand", isPresented: $showingShareAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Share to Feed") {
                showingShareSheet = true
            }
        } message: {
            Text("Would you like to share this hand to your feed?")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareHandView(hand: hand, showingReplay: $showingShareSheet)
                .environmentObject(postService)
                .environmentObject(userService)
        }
    }
    
    private func initializeStacks() {
        hand.raw.players.forEach { player in
            playerStacks[player.name] = player.stack
        }
    }
    
    private func startReplay() {
        currentStreetIndex = 0
        currentActionIndex = 0
        isPlaying = true
        isHandComplete = false
        potAmount = 0
        foldedPlayers.removeAll()
        playerBets.removeAll()
        initializeStacks()
        
        // Set initial blind amounts
        if hand.raw.streets.count > 0 && hand.raw.streets[0].actions.count >= 2 {
            let preflop = hand.raw.streets[0]
            
            // Find small blind action
            if let sbAction = preflop.actions.first(where: { $0.action.lowercased().contains("small blind") }) {
                playerBets[sbAction.playerName] = sbAction.amount
                if let stack = playerStacks[sbAction.playerName] {
                    playerStacks[sbAction.playerName] = stack - sbAction.amount
                }
                potAmount += sbAction.amount
            }
            
            // Find big blind action
            if let bbAction = preflop.actions.first(where: { $0.action.lowercased().contains("big blind") }) {
                playerBets[bbAction.playerName] = bbAction.amount
                if let stack = playerStacks[bbAction.playerName] {
                    playerStacks[bbAction.playerName] = stack - bbAction.amount
                }
                potAmount += bbAction.amount
            }
        }
    }
    
    private func nextAction() {
        guard !isHandComplete else { return }
        
        if currentStreetIndex < hand.raw.streets.count {
            let currentStreet = hand.raw.streets[currentStreetIndex]
            
            if currentActionIndex < currentStreet.actions.count {
                let action = currentStreet.actions[currentActionIndex]
                
                if action.action.lowercased() == "checks" {
                    lastCheckPlayer = action.playerName
                    showCheckAnimation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showCheckAnimation = false
                        }
                    }
                } else {
                    lastCheckPlayer = nil
                    showCheckAnimation = false
                }
                
                // Update game state based on action
                switch action.action.lowercased() {
                case "folds":
                    foldedPlayers.insert(action.playerName)
                    playerBets[action.playerName] = 0
                case "bets", "raises":
                    if let stack = playerStacks[action.playerName] {
                        playerStacks[action.playerName] = stack - action.amount
                        potAmount += action.amount
                        playerBets[action.playerName] = action.amount
                    }
                case "calls":
                    if let stack = playerStacks[action.playerName] {
                        playerStacks[action.playerName] = stack - action.amount
                        potAmount += action.amount
                        playerBets[action.playerName] = action.amount
                    }
                case "small blind", "big blind":
                    break
                default:
                    break
                }
                
                currentActionIndex += 1
            } else if currentStreetIndex + 1 < hand.raw.streets.count {
                currentStreetIndex += 1
                currentActionIndex = 0
                playerBets.removeAll()
            } else {
                // Handle showdown
                withAnimation(.easeInOut(duration: 0.5)) {
                    showdownRevealed = true
                }
                
                // Determine winners and distribute pot
                if let distribution = hand.raw.pot.distribution {
                    winningPlayers = Set(distribution.filter { $0.amount > 0 }.map { $0.playerName })
                    
                    // Animate pot distribution after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            showPotDistribution = true
                            
                            // Update player stacks with winnings
                            for potDist in distribution {
                                if let currentStack = playerStacks[potDist.playerName] {
                                    playerStacks[potDist.playerName] = currentStack + potDist.amount
                                }
                            }
                            potAmount = 0
                        }
                    }
                }
                
                isHandComplete = true
            }
        }
    }
}

struct CommunityCardsView: View {
    let cards: [String]

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                // Flop
                if cards.count >= 3 {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { idx in
                            if idx < cards.count {
                                CardView(card: Card(from: cards[idx]))
                                    .frame(width: 32, height: 46)
                            }
                        }
                    }
                }
                // Turn and River
                HStack(spacing: 8) {
                    if cards.count >= 4 {
                        CardView(card: Card(from: cards[3]))
                            .frame(width: 32, height: 46)
                    }
                    if cards.count >= 5 {
                        CardView(card: Card(from: cards[4]))
                            .frame(width: 32, height: 46)
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct CardView: View {
    let card: Card
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .shadow(radius: 1)
            
            VStack(spacing: 0) {
                Text(card.rank)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(card.suit.lowercased() == "h" || card.suit.lowercased() == "d" ? .red : .black)
                Text(suitSymbol(for: card.suit))
                    .font(.system(size: 14))
                    .foregroundColor(card.suit.lowercased() == "h" || card.suit.lowercased() == "d" ? .red : .black)
            }
        }
    }
    
    private func suitSymbol(for suit: String) -> String {
        switch suit.lowercased() {
        case "h": return "♥️"
        case "d": return "♦️"
        case "c": return "♣️"
        case "s": return "♠️"
        default: return suit
        }
    }
}

struct PlayerSeatView: View {
    let player: Player
    let isFolded: Bool
    let isHero: Bool
    let stack: Double
    let geometry: GeometryProxy
    let allPlayers: [Player]
    let betAmount: Double?
    let showdownRevealed: Bool
    let isWinner: Bool
    let showPotDistribution: Bool
    let showCheck: Bool
    
    @State private var showCards: Bool = true
    
    var displayName: String {
        isHero ? "Hero" : (player.position ?? "")
    }
    
    private let positionOrder = [
        "button",
        "small blind",
        "big blind",
        "utg",
        "utg+1",
        "utg+2",
        "lojack",
        "hijack",
        "cutoff"
    ]
    
    private func getPosition() -> CGPoint {
        let width = geometry.size.width
        let height = geometry.size.height
        
        guard let hero = allPlayers.first(where: { $0.isHero }),
              let heroPosition = hero.position,
              let heroIndex = positionOrder.firstIndex(of: heroPosition) else {
            // fallback
            return CGPoint(x: width * 0.5, y: height * 0.72)
        }
        
        guard let playerPosition = player.position,
              let playerIndex = positionOrder.firstIndex(of: playerPosition) else {
            // fallback
            return CGPoint(x: width * 0.5, y: height * 0.72)
        }
        
        // Calculate relative position (clockwise)
        let relativeIndex = (playerIndex - heroIndex + positionOrder.count) % positionOrder.count
        let tablePositions = [
            CGPoint(x: width * 0.5, y: height * 0.72),  // 0: Hero (bottom center)
            CGPoint(x: width * 0.12, y: height * 0.62),  // 1: Bottom left
            CGPoint(x: width * 0.08, y: height * 0.4),   // 2: Left middle
            CGPoint(x: width * 0.12, y: height * 0.2),   // 3: Left top
            CGPoint(x: width * 0.3, y: height * 0.05),   // 4: Top middle left
            CGPoint(x: width * 0.7, y: height * 0.05),   // 5: Top middle right
            CGPoint(x: width * 0.88, y: height * 0.2),   // 6: Right top
            CGPoint(x: width * 0.92, y: height * 0.4),   // 7: Right middle
            CGPoint(x: width * 0.88, y: height * 0.62),  // 8: Bottom right
        ]
        let pos = tablePositions[relativeIndex]
        
        return pos
    }
    
    private func getBetPosition() -> CGPoint {
        let width = geometry.size.width
        let height = geometry.size.height
        let centerX = width * 0.5
        let centerY = height * 0.35 // Approximate center of the table
        
        // Get the player's current position
        let pos = getPosition()
        
        // Special handling for hero's bet - place it to the right
        if isHero {
            return CGPoint(x: pos.x + 65, y: pos.y) // Increased spacing from 50 to 65
        }
        
        // Calculate vector from center to player
        let vectorX = pos.x - centerX
        let vectorY = pos.y - centerY
        
        // Normalize the vector
        let length = sqrt(vectorX * vectorX + vectorY * vectorY)
        let normalizedX = vectorX / length
        let normalizedY = vectorY / length
        
        // Increased bet distance for more spacing
        let betDistance: CGFloat = 55 // Increased from 40 to 55
        let betX = pos.x - (normalizedX * betDistance)
        let betY = pos.y - (normalizedY * betDistance)
        
        return CGPoint(x: betX, y: betY)
    }
    
    private var shouldShowCards: Bool {
        if isHero {
            return !isFolded && player.cards != nil
        } else {
            // Show villain's cards if:
            // 1. They haven't folded
            // 2. We're at showdown
            // 3. They have cards to show (either hole cards or final cards)
            // 4. They won or showed their cards
            return !isFolded && showdownRevealed && 
                   ((player.finalCards != nil && !player.finalCards!.isEmpty) || 
                    (isWinner && player.cards != nil))
        }
    }
    
    var body: some View {
        let position = getPosition()
        let betPosition = getBetPosition()
        
        let cardWidth: CGFloat = isHero ? 38 : 28
        let cardHeight: CGFloat = isHero ? 56 : 40
        let rectWidth: CGFloat = isHero ? 100 : 70
        let rectHeight: CGFloat = isHero ? 54 : 36
        let fontSize: CGFloat = isHero ? 17 : 13
        let stackFontSize: CGFloat = isHero ? 15 : 11
        let cardOffset: CGFloat = isHero ? -38 : -28
        
        ZStack {
            // Main content in a separate ZStack for proper layering
            ZStack {
                // Cards first (will be behind player info but above table)
                if !isFolded {
                    // Show cards based on whether it's hero or villain and if we're at showdown
                    let cardsToShow: [String] = {
                        if isHero {
                            return player.cards ?? ["?", "?"]
                        } else if showdownRevealed {
                            if let finalCards = player.finalCards, !finalCards.isEmpty {
                                return finalCards
                            }
                            return player.cards ?? ["?", "?"]
                        }
                        return ["?", "?"]
                    }()
                    
                    HStack(spacing: isHero ? 12 : 7) {
                        ForEach(Array(cardsToShow.enumerated()), id: \.offset) { index, card in
                            if card == "?" {
                                ZStack {
                                    RoundedRectangle(cornerRadius: isHero ? 7 : 5)
                                        .fill(Color.gray)
                                        .frame(width: cardWidth, height: cardHeight)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: isHero ? 7 : 5)
                                                .stroke(Color.white, lineWidth: 1)
                                        )
                                    Text("?")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            } else {
                                CardView(card: Card(from: card))
                                    .frame(width: cardWidth, height: cardHeight)
                            }
                        }
                    }
                    .offset(y: isHero ? -32 : cardOffset)
                    .zIndex(1)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showCards)
                }
                
                // Player info rectangle on top
                VStack(spacing: isHero ? 8 : 4) {
                    ZStack {
                        if showCheck {
                            Text("CHECK")
                                .font(.system(size: isHero ? 22 : 16, weight: .bold))
                                .foregroundColor(.yellow)
                                .padding(6)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(8)
                                .transition(.scale.combined(with: .opacity))
                                .zIndex(2)
                        }
                        Text(displayName)
                            .font(.system(size: fontSize, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text(String(format: "$%.0f", stack))
                        .font(.system(size: stackFontSize))
                        .foregroundColor(isWinner ? .green : .white.opacity(0.9))
                }
                .frame(width: rectWidth, height: rectHeight)
                .background(
                    RoundedRectangle(cornerRadius: isHero ? 13 : 10)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: isHero ? 13 : 10)
                                .stroke(isWinner ? Color.green : Color.white.opacity(0.7), lineWidth: isWinner ? 2 : 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                )
                .scaleEffect(isWinner && showPotDistribution ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isWinner && showPotDistribution)
                .zIndex(2)  // Highest z-index for player info
                .opacity(isFolded ? 0.5 : 1.0)
            }
            .position(x: position.x, y: position.y)
            
            // Bet amount in separate layer
            if let bet = betAmount, bet > 0 {
                ChipView(amount: bet)
                    .scaleEffect(0.8)
                    .position(x: betPosition.x, y: betPosition.y)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(3)  // Always on top
            }
        }
        .onAppear {
            showCards = true
        }
        .onChange(of: isFolded) { folded in
            withAnimation {
                showCards = !folded
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCheck)
    }
}

// Update ChipView to match mockup style
struct ChipView: View {
    let amount: Double
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.3), radius: 2)
            Circle()
                .fill(Color.green.opacity(0.9))
                .frame(width: 46, height: 46)
            Text("$\(Int(amount))")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct ActionLogView: View {
    let hand: ParsedHandHistory
    let currentStreetIndex: Int
    let currentActionIndex: Int
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0...currentStreetIndex, id: \.self) { streetIndex in
                    let street = hand.raw.streets[streetIndex]
                    ForEach(0..<(streetIndex == currentStreetIndex ? currentActionIndex : street.actions.count), id: \.self) { actionIndex in
                        let action = street.actions[actionIndex]
                        Text("\(action.playerName) \(action.action) \(action.amount > 0 ? "$\(Int(action.amount))" : "")")
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
        }
        .background(Color.clear) // Fully transparent
        .cornerRadius(12)
    }
}

// Update the main view's frame to ensure everything is centered
extension View {
    func centerInParent() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)
    }
}

struct ShareHandView: View {
    let hand: ParsedHandHistory
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var userService: UserService
    @State private var postText = ""
    @State private var isLoading = false
    @FocusState private var isTextEditorFocused: Bool
    @Binding var showingReplay: Bool
    
    private var heroName: String? {
        hand.raw.players.first(where: { $0.isHero })?.name
    }
    
    private var heroPnl: Double {
        hand.raw.pot.heroPnl ?? 0
    }
    
    private var formattedPnl: String {
        if heroPnl >= 0 {
            return "+$\(Int(heroPnl))"
        } else {
            return "-$\(abs(Int(heroPnl)))"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0)).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 12) {
                        if let profileImage = userService.currentUserProfile?.avatarURL {
                            AsyncImage(url: URL(string: profileImage)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if let username = userService.currentUserProfile?.username {
                                Text(username)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("Share your hand")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Hand Summary
                    VStack(alignment: .leading, spacing: 12) {
                        if let hero = hand.raw.players.first(where: { $0.isHero }) {
                            HStack(spacing: 8) {
                                ForEach(hero.cards ?? [], id: \.self) { card in
                                    CardView(card: Card(from: card))
                                        .frame(width: 32, height: 46)
                                }
                            }
                            
                            if let finalHand = hero.finalHand {
                                Text("Best Hand: \(finalHand)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Text("P/L: \(formattedPnl)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(heroPnl >= 0 ? .green : .red)
                        }
                    }
                    .padding()
                    .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 0.5)))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Text Editor
                    TextEditor(text: $postText)
                        .focused($isTextEditorFocused)
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .frame(maxHeight: .infinity)
                        .padding()
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                    
                    // Bottom toolbar
                    HStack {
                        Spacer()
                        Text("\(280 - postText.count)")
                            .foregroundColor(postText.count > 280 ? .red : .gray)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding()
                    .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 0.95)))
                }
            }
            .navigationTitle("Share Hand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareHand) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Share")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || postText.count > 280)
                    .foregroundColor(postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || postText.count > 280 ? .gray : .white)
                }
            }
        }
        .onAppear {
            isTextEditorFocused = true
        }
    }
    
    private func shareHand() {
        guard !postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let userId = userService.currentUserProfile?.id,
              let username = userService.currentUserProfile?.username,
              let profileImage = userService.currentUserProfile?.avatarURL else { return }
        
        isLoading = true
        
        Task {
            do {
                try await postService.createHandPost(
                    content: postText,
                    userId: userId,
                    username: username,
                    profileImage: profileImage,
                    hand: hand
                )
                try await postService.fetchPosts()
                DispatchQueue.main.async {
                    dismiss()
                    showingReplay = false
                }
            } catch {
                print("Error sharing hand: \(error)")
            }
            isLoading = false
        }
    }
} 