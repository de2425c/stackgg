import SwiftUI

struct HandSummaryRow: View {
    let hand: ParsedHandHistory
    @State private var showingReplay = false
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var userService: UserService
    
    private func formatMoney(_ amount: Double) -> String {
        if amount >= 0 {
            return "$\(Int(amount))"
        } else {
            return "$\(abs(Int(amount)))"
        }
    }
    
    private var heroCards: [Card]? {
        if let hero = hand.raw.players.first(where: { $0.isHero }),
           let cards = hero.cards {
            return cards.map { Card(from: $0) }
        }
        return nil
    }
    
    private var handStrength: String? {
        hand.raw.players.first(where: { $0.isHero })?.finalHand
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: Stakes and PnL
            HStack(alignment: .center) {
                // Stakes
                Text("\(formatMoney(hand.raw.gameInfo.smallBlind))/\(formatMoney(hand.raw.gameInfo.bigBlind))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 40/255, green: 40/255, blue: 45/255),
                                    Color(red: 50/255, green: 50/255, blue: 55/255)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                
                Spacer()
                
                // PnL
                if let hero = hand.raw.players.first(where: { $0.isHero }) {
                    let pnl = hand.raw.pot.heroPnl ?? 0
                    Text(formatMoney(pnl))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(pnl >= 0 ? Color(red: 123/255, green: 255/255, blue: 99/255) : .red)
                        .shadow(color: pnl >= 0 ? Color(red: 123/255, green: 255/255, blue: 99/255).opacity(0.3) : .red.opacity(0.3), radius: 4)
                }
            }
            
            // Middle row: Cards and Hand Strength
            HStack(alignment: .center, spacing: 12) {
                // Hero's Cards
                if let cards = heroCards {
                    HStack(spacing: 4) {
                        ForEach(cards, id: \.id) { card in
                            CardView(card: card)
                                .frame(width: 32, height: 44)
                                .shadow(color: .black.opacity(0.2), radius: 2)
                        }
                    }
                }
                
                if let strength = handStrength {
                    Text(strength)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 60/255, green: 60/255, blue: 70/255),
                                        Color(red: 45/255, green: 45/255, blue: 55/255)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )
                }
                
                Spacer()
                
                // Replay button
                HStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16))
                    Text("Replay Hand")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 70/255, green: 70/255, blue: 80/255),
                                Color(red: 55/255, green: 55/255, blue: 65/255)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            
            // Bottom row: Best Hand (if available)
            if let strength = handStrength {
                Text("Best Hand: \(strength)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 35/255, green: 35/255, blue: 40/255),
                                    Color(red: 30/255, green: 30/255, blue: 35/255)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
        .onTapGesture {
            showingReplay = true
        }
        .sheet(isPresented: $showingReplay) {
            HandReplayView(hand: hand)
                .environmentObject(postService)
                .environmentObject(userService)
        }
    }
} 
