import SwiftUI

struct HandSummaryRow: View {
    let hand: ParsedHandHistory
    
    private var heroPosition: String {
        if let hero = hand.raw.players.first(where: { $0.isHero }) {
            return hero.position ?? "Unknown"
        }
        return "Unknown"
    }
    
    private var heroCards: [String] {
        if let hero = hand.raw.players.first(where: { $0.isHero }) {
            return hero.cards ?? []
        }
        return []
    }
    
    private var heroWon: Bool {
        guard let distribution = hand.raw.pot.distribution,
              let hero = hand.raw.players.first(where: { $0.isHero }) else {
            return false
        }
        return distribution.contains { potDist in
            potDist.playerName == hero.name && potDist.amount > 0
        }
    }
    
    private func formatMoney(_ amount: Double) -> String {
        let formatted = String(format: "%.0f", amount)
        return "$\(formatted)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with blinds and position
            HStack {
                Text("\(formatMoney(hand.raw.gameInfo.smallBlind))/\(formatMoney(hand.raw.gameInfo.bigBlind))")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(heroPosition)
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
            }
            
            // Hero's cards
            HStack(spacing: 4) {
                ForEach(heroCards, id: \.self) { card in
                    Text(card)
                        .font(.system(size: 20))
                        .foregroundColor(heroWon ? Color.green : Color.red)
                }
            }
            
            // Final pot
            Text("Final pot: \(formatMoney(hand.raw.pot.amount))")
                .font(.system(size: 15))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
        .cornerRadius(12)
    }
} 