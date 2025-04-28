import SwiftUI

struct AnalyticsView: View {
    @ObservedObject var sessionStore: SessionStore
    
    private var totalProfit: Double {
        sessionStore.sessions.reduce(0) { $0 + $1.profit }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Bankroll section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bankroll")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("$\(Int(totalProfit))")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Profit Graph
                ProfitGraph(sessionStore: sessionStore)
                    .padding(.horizontal)
                
                // Selected Hands section (placeholder for now)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Selected Hands")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("Coming soon...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.systemGray6))
                )
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.black)
    }
} 