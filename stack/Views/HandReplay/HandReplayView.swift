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
    @State private var isShowdownComplete = false
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var userService: UserService
    
    private let tableColor = Color(red: 45/255, green: 120/255, blue: 65/255)
    private let tableBorderColor = Color(red: 74/255, green: 54/255, blue: 38/255)
    
    private var hasMoreActions: Bool {
        guard currentStreetIndex < hand.raw.streets.count else { return false }
        let currentStreet = hand.raw.streets[currentStreetIndex]
        return currentActionIndex < currentStreet.actions.count || currentStreetIndex + 1 < hand.raw.streets.count
    }
    
    // This ensures we accumulate all community cards as the hand progresses
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
                        
                        // Stack Logo - positioned above pot
                        Text("STACK")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(0.3)
                            .offset(y: -geometry.size.height * 0.12) // Moved up above pot

                        // Pot display - centered at middle of table
                        if potAmount > 0 {
                            ChipView(amount: potAmount)
                                .scaleEffect(1.2) // Scale up for better visibility
                                .transition(.scale.combined(with: .opacity))
                                .animation(.spring(response: 0.4), value: potAmount)
                                .offset(y: geometry.size.height * 0.02) // Moved down further
                        }

                        // Community Cards - positioned closer to hero
                        CommunityCardsView(cards: allCommunityCards)
                            .offset(y: geometry.size.height * 0.10) // Adjusted position
                            .scaleEffect(1.15) // Make it slightly larger overall

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
                                showCheck: showCheckAnimation && lastCheckPlayer == player.name,
                                isPlayingHand: isPlaying,
                                isHandComplete: isHandComplete,
                                isShowdownComplete: isShowdownComplete
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
        // Reset all state
        currentStreetIndex = 0
        currentActionIndex = 0
        isPlaying = true
        isHandComplete = false
        potAmount = 0
        foldedPlayers.removeAll()
        playerBets.removeAll()
        showdownRevealed = false
        winningPlayers.removeAll()
        showPotDistribution = false
        lastCheckPlayer = nil
        showCheckAnimation = false
        isShowdownComplete = false
        
        print("DEBUG - startReplay(): All state reset, isShowdownComplete=false")
        
        // Initialize player stacks to their starting values
        initializeStacks()
    }
    
    private func nextAction() {
        guard !isHandComplete else { return }
        
        if currentStreetIndex < hand.raw.streets.count {
            let currentStreet = hand.raw.streets[currentStreetIndex]
            
            if currentActionIndex < currentStreet.actions.count {
                let action = currentStreet.actions[currentActionIndex]
                
                // Check animation handling
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
                
                // Process the current action
                processAction(action)
                
                currentActionIndex += 1
            } else if currentStreetIndex + 1 < hand.raw.streets.count {
                // Move to the next street
                currentStreetIndex += 1
                currentActionIndex = 0
                
                // Clear bet displays but NOT the pot amount
                playerBets.removeAll()
            } else {
                // No more actions or streets - time for showdown
                handleShowdown()
            }
        }
    }
    
    private func processAction(_ action: Action) {
        switch action.action.lowercased() {
        case "folds":
            foldedPlayers.insert(action.playerName)
            playerBets[action.playerName] = nil // Remove any existing bet display
            
        case "bets":
            if let stack = playerStacks[action.playerName] {
                // Subtract from player's stack
                playerStacks[action.playerName] = stack - action.amount
                
                // Add to pot
                potAmount += action.amount
                
                // Display the bet
                playerBets[action.playerName] = action.amount
            }
            
        case "raises":
            if let stack = playerStacks[action.playerName] {
                // Subtract from player's stack
                playerStacks[action.playerName] = stack - action.amount
                
                // Add to pot
                potAmount += action.amount
                
                // Display the bet
                playerBets[action.playerName] = action.amount
            }
            
        case "calls":
            if let stack = playerStacks[action.playerName] {
                // Subtract from player's stack
                playerStacks[action.playerName] = stack - action.amount
                
                // Add to pot
                potAmount += action.amount
                
                // If player already has a bet, add to it (for blinds or previous street action)
                if let existingBet = playerBets[action.playerName] {
                    playerBets[action.playerName] = existingBet + action.amount
                } else {
                    playerBets[action.playerName] = action.amount
                }
            }
            
        case "checks":
            // No changes to stacks or pot for checks
            break
            
        default:
            // Handle "Bets" for blinds - special case
            if action.amount > 0 {
                if let stack = playerStacks[action.playerName] {
                    // Subtract from player's stack
                    playerStacks[action.playerName] = stack - action.amount
                    
                    // Add to pot
                    potAmount += action.amount
                    
                    // Display the bet
                    playerBets[action.playerName] = action.amount
                }
            }
        }
    }
    
    private func handleShowdown() {
        print("DEBUG - handleShowdown() called - Setting isShowdownComplete=true")
        
        // Reveal cards at showdown
        withAnimation(.easeInOut(duration: 0.5)) {
            showdownRevealed = true
        }
        
        // Determine winners based on pot distribution
        if let distribution = hand.raw.pot.distribution {
            winningPlayers = Set(distribution.filter { $0.amount > 0 }.map { $0.playerName })
            
            // Animate pot distribution after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showPotDistribution = true
                    
                    // Update player stacks with winnings
                    for potDist in distribution {
                        if let currentStack = self.playerStacks[potDist.playerName] {
                            self.playerStacks[potDist.playerName] = currentStack + potDist.amount
                        }
                    }
                    self.potAmount = 0
                }
            }
        }
        
        isHandComplete = true
        
        isShowdownComplete = true
    }
}

struct CommunityCardsView: View {
    let cards: [String]

    var body: some View {
        VStack(spacing: 4) {
            // Flop, Turn, River label
            Text(getStreetLabel())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 2)
            
            // All cards in one row
            HStack(spacing: 5) {
                ForEach(0..<5) { idx in
                    if idx < cards.count {
                        CardView(card: Card(from: cards[idx]))
                            .frame(width: 38, height: 52)
                            .shadow(color: .black.opacity(0.6), radius: 1)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: cards.count)
                    } else {
                        // Empty placeholder
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.clear)
                            .frame(width: 38, height: 52)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.1, green: 0.3, blue: 0.1))
                .shadow(color: .black.opacity(0.5), radius: 2)
        )
    }
    
    // Get label for current street
    private func getStreetLabel() -> String {
        switch cards.count {
        case 0: return "Pre-Flop"
        case 3: return "Flop"
        case 4: return "Turn"
        case 5: return "River"
        default: return ""
        }
    }
}

struct CardView: View {
    let card: Card
    
    // Get color based on suit
    private var cardBackgroundColor: Color {
        switch card.suit.lowercased() {
        case "s": return Color(red: 0.1, green: 0.2, blue: 0.5) // Spades - dark blue
        case "h": return Color(red: 0.5, green: 0.1, blue: 0.1) // Hearts - dark red
        case "d": return Color(red: 0.1, green: 0.4, blue: 0.6) // Diamonds - medium blue
        case "c": return Color(red: 0.1, green: 0.3, blue: 0.2) // Clubs - dark green
        default: return Color(red: 0.1, green: 0.25, blue: 0.5) // Default blue
        }
    }
    
    private var suitColor: Color {
        card.suit.lowercased() == "h" || card.suit.lowercased() == "d" ? .red : .white
    }
    
    var body: some View {
        ZStack {
            // Card background - color based on suit
            RoundedRectangle(cornerRadius: 5)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.black.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 1)
            
            // Card content - simplified design matching image
            VStack {
                // Top left - rank and suit
                HStack {
                    VStack(alignment: .leading, spacing: -2) {
                        Text(formatRank(card.rank))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(suitSymbol(for: card.suit))
                            .font(.system(size: 14))
                            .foregroundColor(suitColor)
                    }
                    .padding(.leading, 4)
                    .padding(.top, 2)
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
    }
    
    private func suitSymbol(for suit: String) -> String {
        switch suit.lowercased() {
        case "h": return "♥"
        case "d": return "♦"
        case "c": return "♣"
        case "s": return "♠"
        default: return suit
        }
    }
    
    // Format card ranks for better display
    private func formatRank(_ rank: String) -> String {
        switch rank {
        case "T": return "10"
        default: return rank
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
    let isPlayingHand: Bool
    let isHandComplete: Bool
    let isShowdownComplete: Bool
    
    @State private var showCards: Bool = true
    
    var displayName: String {
        isHero ? "Hero" : (player.position ?? "")
    }
    
    // Check if this player is on the button
    private var isOnButton: Bool {
        return player.position == "button"
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
        let centerY = height * 0.4 // Adjusted center of the table
        
        // Get the player's current position
        let pos = getPosition()
        
        // Calculate vector from center to player position
        let vectorX = pos.x - centerX
        let vectorY = pos.y - centerY
        
        // Normalize the vector
        let length = sqrt(vectorX * vectorX + vectorY * vectorY)
        let normalizedX = vectorX / length
        let normalizedY = vectorY / length
        
        // Special positioning for different seat positions
        if isHero {
            // For hero, place bet to the right side
            return CGPoint(x: pos.x + 85, y: pos.y)
        } else if player.position == "small blind" {
            // For small blind on the left, place bet to the right to avoid overlap
            return CGPoint(x: pos.x + 65, y: pos.y)
        } else if player.position == "big blind" {
            // For big blind, place bet to the right
            return CGPoint(x: pos.x + 65, y: pos.y + 10)
        } else if player.position == "cutoff" {
            // For cutoff on the right, place bet to the left
            return CGPoint(x: pos.x - 65, y: pos.y)
        } else if ["hijack", "lojack"].contains(player.position) {
            // Right side positions
            return CGPoint(x: pos.x - 65, y: pos.y + 10)
        } else if ["utg", "utg+1", "utg+2"].contains(player.position) {
            // Left side positions
            return CGPoint(x: pos.x + 65, y: pos.y + 10)
        } else {
            // For positions at the top of the table, place bets below
            return CGPoint(x: pos.x, y: pos.y + 55)
        }
    }
    
    // Position for the dealer button
    private func getDealerButtonPosition() -> CGPoint {
        let position = getPosition()
        
        // Position the dealer button based on seat location
        if isHero {
            // Bottom center - place button to the left
            return CGPoint(x: position.x - 55, y: position.y - 2)
        } else if player.position == "small blind" {
            // Bottom left - place button to the right
            return CGPoint(x: position.x + 45, y: position.y - 7)
        } else if player.position == "cutoff" {
            // Bottom right - place button to the left
            return CGPoint(x: position.x - 45, y: position.y - 7)
        } else if ["hijack", "lojack"].contains(player.position) {
            // Right side - place button to the left
            return CGPoint(x: position.x - 45, y: position.y - 2)
        } else if ["utg", "utg+1", "utg+2"].contains(player.position) {
            // Left side - place button to the right
            return CGPoint(x: position.x + 45, y: position.y - 2)
        } else {
            // Top - place button below
            return CGPoint(x: position.x, y: position.y + 35)
        }
    }
    
    private var shouldShowCards: Bool {
        // If player has folded, don't show cards
        if isFolded {
            return false
        }
        
        // Otherwise, always show cards (blank or real)
        return true
    }
    
    // Whether to show the actual card values or just back-faced cards
    private var shouldRevealCardValues: Bool {
        // Hero's cards are always revealed if not folded
        if isHero && !isFolded {
            return true
        }
        
        // For villains, ONLY show cards at showdown when we've actually completed all actions
        if !isFolded && isShowdownComplete {
            return true
        }
        
        return false
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
                if shouldShowCards {
                    HStack(spacing: isHero ? 12 : 7) {
                        ForEach(0..<2, id: \.self) { index in
                            if shouldRevealCardValues {
                                // At showdown, show finalCards if available, otherwise fall back to regular cards
                                if showdownRevealed && player.finalCards != nil && index < player.finalCards!.count {
                                    CardView(card: Card(from: player.finalCards![index]))
                                        .frame(width: cardWidth, height: cardHeight)
                                } else if let cards = player.cards, index < cards.count {
                                    CardView(card: Card(from: cards[index]))
                                        .frame(width: cardWidth, height: cardHeight)
                                }
                            } else {
                                // Otherwise show a blank card
                                ZStack {
                                    RoundedRectangle(cornerRadius: isHero ? 7 : 5)
                                        .fill(Color.gray)
                                        .frame(width: cardWidth, height: cardHeight)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: isHero ? 7 : 5)
                                                .stroke(Color.white, lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                    .offset(y: isHero ? -32 : cardOffset)
                    .zIndex(1)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showCards)
                }
                
                // Player info rectangle on top
                VStack(spacing: isHero ? 4 : 4) {
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
                            .font(.system(size: isHero ? 20 : fontSize, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text(String(format: "$%.0f", stack))
                        .font(.system(size: isHero ? 18 : stackFontSize, weight: isHero ? .medium : .regular))
                        .foregroundColor(isWinner ? .green : .white.opacity(0.9))
                }
                .frame(width: isHero ? 110 : rectWidth, height: isHero ? 60 : rectHeight)
                .background(
                    RoundedRectangle(cornerRadius: isHero ? 13 : 10)
                        .fill(Color.black.opacity(isHero ? 0.9 : 0.8))
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
            
            // Dealer button only for the player on the button
            if isOnButton {
                DealerButtonView()
                    .scaleEffect(0.8)
                    .position(getDealerButtonPosition())
                    .zIndex(3)
            }
            
            // Bet amount in separate layer
            if let bet = betAmount, bet > 0 {
                ChipView(amount: bet)
                    .scaleEffect(isHero ? 1.0 : 0.8) // Larger chips for hero
                    .position(x: betPosition.x, y: betPosition.y)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: bet)
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

// Dealer button view
struct DealerButtonView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.9),
                        Color.gray.opacity(0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.4), radius: 1)
            
            Text("D")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
        }
    }
}

// Update ChipView for better aesthetics
struct ChipView: View {
    let amount: Double
    
    // Define chip denominations and their colors
    private let chipDenominations: [(value: Int, color: Color)] = [
        (500, Color(red: 0.6, green: 0.0, blue: 0.6)), // Purple for 500
        (100, Color(red: 0.0, green: 0.0, blue: 0.8)), // Blue for 100
        (25, Color(red: 0.9, green: 0.0, blue: 0.0)),  // Red for 25
        (5, Color(red: 0.0, green: 0.6, blue: 0.0)),   // Green for 5
        (1, Color(red: 0.5, green: 0.5, blue: 0.5))    // Gray for 1
    ]
    
    // Calculate how many of each chip to display
    private func calculateChips() -> [(value: Int, count: Int, color: Color)] {
        let intAmount = Int(amount)
        var remainingAmount = intAmount
        var result: [(value: Int, count: Int, color: Color)] = []
        
        for (value, color) in chipDenominations {
            if remainingAmount >= value {
                let count = min(remainingAmount / value, 3) // Cap at 3 chips per denomination for visual clarity
                remainingAmount -= count * value
                result.append((value: value, count: count, color: color))
            }
        }
        
        // Limit to 3 different denominations for visual clarity
        if result.count > 3 {
            result = Array(result.prefix(3))
        }
        
        return result
    }
    
    var body: some View {
        let chipStacks = calculateChips()
        
        return ZStack {
            // Chip stack
            VStack(alignment: .center, spacing: 0) {
                HStack(alignment: .bottom, spacing: -2) {
                    // Create the chip stacks side by side for a more compact look
                    ForEach(0..<chipStacks.count, id: \.self) { stackIndex in
                        let stack = chipStacks[stackIndex]
                        ZStack {
                            // Stack the chips of the same value
                            ForEach(0..<stack.count, id: \.self) { chipIndex in
                                PokerChip(color: stack.color)
                                    .offset(y: CGFloat(-chipIndex * 2)) // Slightly offset each chip for 3D effect
                            }
                        }
                    }
                }
                
                // Amount text below the chips
                Text("$\(Int(amount))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(6)
                    .padding(.top, 2)
            }
        }
        .frame(width: 55, height: 40)
    }
}

// Individual poker chip component
struct PokerChip: View {
    let color: Color
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
            
            // Colored center
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            color,
                            color.opacity(0.7)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 18, height: 18)
            
            // Inner pattern ring
            Circle()
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
                .frame(width: 15, height: 15)
            
            // Edge detail
            Circle()
                .stroke(Color.white, lineWidth: 1)
                .frame(width: 22, height: 22)
        }
        .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
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
                            if let displayName = userService.currentUserProfile?.displayName,
                               !displayName.isEmpty {
                                Text(displayName)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            } else if let username = userService.currentUserProfile?.username {
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
        
        let displayName = userService.currentUserProfile?.displayName
        
        isLoading = true
        
        Task {
            do {
                try await postService.createHandPost(
                    content: postText,
                    userId: userId,
                    username: username,
                    displayName: displayName,
                    profileImage: profileImage,
                    hand: hand
                )
                try await postService.fetchPosts()
                DispatchQueue.main.async {
                    // Dismiss the share sheet
                    dismiss()
                    // Close the replayer
                    showingReplay = false
                    
                    // Navigate to the feed tab
                    navigateToFeedTab()
                }
            } catch {
                print("Error sharing hand: \(error)")
            }
            isLoading = false
        }
    }
    
    private func navigateToFeedTab() {
        // Find the top-most view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Access the TabView controller in HomePage
        var current = rootVC
        while let presented = current.presentedViewController {
            current = presented
        }
        
        // Post a notification to tell HomePage to switch to the feed tab
        NotificationCenter.default.post(name: NSNotification.Name("SwitchToFeedTab"), object: nil)
    }
} 
