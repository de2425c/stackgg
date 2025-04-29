import SwiftUI

struct AnalyticsView: View {
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var handStore: HandStore
    
    private var totalProfit: Double {
        sessionStore.sessions.reduce(0) { $0 + $1.profit }
    }
    
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
                // Profit Graph Section
                VStack(spacing: 16) {
                    HStack {
                        Text("Total Profit")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("$\(Int(totalProfit))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(totalProfit >= 0 ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : .red)
                    }
                    .padding(.horizontal)
                    
                    ProfitGraph(sessionStore: sessionStore)
                }
                .padding(.vertical, 16)
                .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Selected Hands section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Notable Hands")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        if let win = biggestWin {
                            AnalyticsCard(title: "Biggest Win", savedHand: win, amount: winAmount(for: win, hero: heroName ?? ""), highlightColor: Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                        }
                        if let loss = biggestLoss {
                            AnalyticsCard(title: "Biggest Loss", savedHand: loss, amount: winAmount(for: loss, hero: heroName ?? ""), highlightColor: Color(red: 1, green: 0.3, blue: 0.3))
                        }
                        if let best = bestHand, handRank(for: best, hero: heroName ?? "") > 0 {
                            AnalyticsCard(title: "Best Hand", savedHand: best, amount: winAmount(for: best, hero: heroName ?? ""), highlightColor: .blue, showHand: true)
                        }
                        
                        if biggestWin == nil && biggestLoss == nil && bestHand == nil {
                            HStack {
                                Spacer()
                                Text("No hands recorded yet")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                            }
                            .padding()
                            .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(UIColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0)))
        .onAppear {
            sessionStore.fetchSessions()
        }
    }
} 