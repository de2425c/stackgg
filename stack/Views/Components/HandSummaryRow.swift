import SwiftUI

struct HandSummaryRow: View {
    let hand: ParsedHandHistory
    @State private var showingReplay = false
    
    private func formatMoney(_ amount: Double) -> String {
        return "$\(Int(amount))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Game Info and Profit/Loss
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(formatMoney(hand.raw.gameInfo.smallBlind))/\(formatMoney(hand.raw.gameInfo.bigBlind))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    if let hero = hand.raw.players.first(where: { $0.isHero }) {
                        Text(hero.finalHand ?? "")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                if let amount = hand.raw.pot.distribution?.first(where: { $0.playerName == hand.raw.players.first(where: { $0.isHero })?.name })?.amount {
                    Text(amount > 0 ? "+$\(Int(amount))" : "-$\(abs(Int(amount)))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(amount > 0 ? .green : .red)
                }
            }
            
            // Hero's Cards
            if let hero = hand.raw.players.first(where: { $0.isHero }) {
                HStack(spacing: 8) {
                    ForEach(hero.cards ?? [], id: \.self) { card in
                        CardView(card: Card(from: card))
                            .frame(width: 32, height: 46)
                    }
                    Spacer()
                    Button(action: { showingReplay = true }) {
                        Text("Replay Hand")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(16)
        .fullScreenCover(isPresented: $showingReplay) {
            HandReplayView(hand: hand)
        }
    }
} 