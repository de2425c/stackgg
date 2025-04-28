import SwiftUI
import FirebaseFirestore

struct DashboardView: View {
    @StateObject private var handStore: HandStore
    @State private var selectedTab = 0
    private let tabs = ["Analytics", "Hands", "Sessions"]
    
    init(userId: String) {
        _handStore = StateObject(wrappedValue: HandStore(userId: userId))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Tab Bar
                    HStack(spacing: 24) {
                        ForEach(0..<tabs.count, id: \.self) { index in
                            TabButton(
                                title: tabs[index],
                                isSelected: selectedTab == index
                            ) {
                                withAnimation {
                                    selectedTab = index
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Content
                    TabView(selection: $selectedTab) {
                        AnalyticsTab(handStore: handStore)
                            .tag(0)
                        
                        HandsTab(handStore: handStore)
                            .tag(1)
                        
                        SessionsTab(userId: handStore.userId)
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "chart.line.uptrend.xyaxis") // or your app icon
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "bell")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
                
                // Underline
                Rectangle()
                    .fill(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                    .frame(height: 2)
                    .opacity(isSelected ? 1 : 0)
            }
        }
    }
}

struct AnalyticsTab: View {
    @ObservedObject var handStore: HandStore

    private var heroName: String? {
        handStore.savedHands.first?.hand.raw.players.first(where: { $0.isHero })?.name
    }

    private var biggestWin: SavedHand? {
        guard let hero = heroName else { return nil }
        return handStore.savedHands.max(by: { winAmount(for: $0, hero: hero) < winAmount(for: $1, hero: hero) })
    }

    private var biggestLoss: SavedHand? {
        guard let hero = heroName else { return nil }
        return handStore.savedHands.min(by: { winAmount(for: $0, hero: hero) < winAmount(for: $1, hero: hero) })
    }

    private var bestHand: SavedHand? {
        guard let hero = heroName else { return nil }
        return handStore.savedHands.max(by: { handRank(for: $0, hero: hero) < handRank(for: $1, hero: hero) })
    }

    private func winAmount(for savedHand: SavedHand, hero: String) -> Double {
        guard let dist = savedHand.hand.raw.pot.distribution else { return 0 }
        return dist.first(where: { $0.playerName == hero })?.amount ?? 0
    }

    private func handRank(for savedHand: SavedHand, hero: String) -> Int {
        let handString = savedHand.hand.raw.players.first(where: { $0.isHero })?.finalHand ?? ""
        return pokerHandRank(handString)
    }

    private func pokerHandRank(_ hand: String) -> Int {
        // Higher is better
        let ranks = [
            "High Card": 1,
            "Pair": 2,
            "Two Pair": 3,
            "Three of a Kind": 4,
            "Straight": 5,
            "Flush": 6,
            "Full House": 7,
            "Four of a Kind": 8,
            "Straight Flush": 9,
            "Royal Flush": 10
        ]
        for (key, value) in ranks.sorted(by: { $0.value > $1.value }) {
            if hand.localizedCaseInsensitiveContains(key) { return value }
        }
        return 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let win = biggestWin {
                    AnalyticsCard(title: "Biggest Win", savedHand: win, amount: winAmount(for: win, hero: heroName ?? ""), highlightColor: .green)
                }
                if let loss = biggestLoss {
                    AnalyticsCard(title: "Biggest Loss", savedHand: loss, amount: winAmount(for: loss, hero: heroName ?? ""), highlightColor: Color(red: 1, green: 0.3, blue: 0.3))
                }
                if let best = bestHand, handRank(for: best, hero: heroName ?? "") > 0 {
                    AnalyticsCard(title: "Best Hand", savedHand: best, amount: winAmount(for: best, hero: heroName ?? ""), highlightColor: .blue, showHand: true)
                }
            }
            .padding()
        }
    }
}

struct AnalyticsCard: View {
    let title: String
    let savedHand: SavedHand
    let amount: Double
    let highlightColor: Color
    var showHand: Bool = false
    @State private var showingReplay = false

    private var hero: Player? {
        savedHand.hand.raw.players.first(where: { $0.isHero })
    }
    private var heroCards: [String] {
        hero?.finalCards ?? hero?.cards ?? []
    }
    private var handType: String {
        hero?.finalHand ?? "-"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(highlightColor)
                Spacer()
                Text("$\(Int(amount))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(highlightColor)
            }
            Divider().background(Color.white.opacity(0.1))
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    if showHand {
                        Text(handType)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    HStack(spacing: 8) {
                        ForEach(heroCards, id: \.self) { card in
                            CardView(card: Card(from: card))
                                .frame(width: 32, height: 46)
                        }
                    }
                }
                Spacer()
                Button(action: { showingReplay = true }) {
                    Text("Replay")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 22)
                        .background(highlightColor.opacity(0.8))
                        .cornerRadius(14)
                }
            }
        }
        .padding()
        .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
        .cornerRadius(16)
        .shadow(color: highlightColor.opacity(0.15), radius: 8, y: 2)
        .fullScreenCover(isPresented: $showingReplay) {
            HandReplayView(hand: savedHand.hand)
        }
    }
}

struct HandsTab: View {
    @ObservedObject var handStore: HandStore
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(handStore.savedHands) { savedHand in
                    HandSummaryRow(hand: savedHand.hand)
                        .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

struct SessionsTab: View {
    @StateObject private var sessionStore: SessionStore
    
    init(userId: String) {
        _sessionStore = StateObject(wrappedValue: SessionStore(userId: userId))
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sessionStore.sessions) { session in
                    SessionSummaryRow(session: session)
                        .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

