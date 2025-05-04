import SwiftUI

struct HandsListView: View {
    @ObservedObject var handStore: HandStore
    
    var body: some View {
        ZStack {
            // Apply new background view
            AppBackgroundView()
                
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(handStore.savedHands) { savedHand in
                        HandSummaryRow(hand: savedHand.hand, id: savedHand.id)
                            .background(Color.clear)
                            .cornerRadius(12)
                            .environmentObject(handStore)
                    }
                }
                .padding()
            }
        }
    }
}

// ... existing code ... 