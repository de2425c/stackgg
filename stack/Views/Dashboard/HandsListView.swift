import SwiftUI
import FirebaseFirestore

struct HandsListView: View {
    @StateObject private var handStore: HandStore
    @State private var isLoadingMore = false
    @State private var lastDocument: DocumentSnapshot? = nil
    @State private var allLoaded = false

    init(userId: String) {
        _handStore = StateObject(wrappedValue: HandStore(userId: userId))
    }

    var body: some View {
        List {
            ForEach(handStore.savedHands) { savedHand in
                HandRowView(savedHand: savedHand)
                    .onAppear {
                        // Trigger load more when the last item appears
                        if savedHand.id == handStore.savedHands.last?.id {
                            loadMoreHandsIfNeeded()
                        }
                    }
            }
            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .onAppear {
            // Initial load
            if handStore.savedHands.isEmpty {
                loadInitialHands()
            }
        }
    }

    // MARK: - Pagination Logic

    private func loadInitialHands() {
        isLoadingMore = true
        let db = Firestore.firestore()
        let userId = handStore.userId
        db.collection("users")
            .document(userId)
            .collection("hands")
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
            .getDocuments { snapshot, error in
                isLoadingMore = false
                guard let snapshot = snapshot else { return }
                let newHands = snapshot.documents.compactMap { doc -> SavedHand? in
                    guard let dict = doc.data()["hand"] as? [String: Any],
                          let data = try? JSONSerialization.data(withJSONObject: dict),
                          let hand = try? JSONDecoder().decode(ParsedHandHistory.self, from: data),
                          let timestamp = doc.data()["timestamp"] as? Timestamp
                    else { return nil }
                    return SavedHand(
                        id: doc.documentID,
                        hand: hand,
                        timestamp: timestamp.dateValue()
                    )
                }
                handStore.savedHands = newHands
                lastDocument = snapshot.documents.last
                allLoaded = newHands.count < 10
            }
    }

    private func loadMoreHandsIfNeeded() {
        guard !isLoadingMore, !allLoaded, let lastDoc = lastDocument else { return }
        isLoadingMore = true
        let db = Firestore.firestore()
        let userId = handStore.userId
        db.collection("users")
            .document(userId)
            .collection("hands")
            .order(by: "timestamp", descending: true)
            .start(afterDocument: lastDoc)
            .limit(to: 10)
            .getDocuments { snapshot, error in
                isLoadingMore = false
                guard let snapshot = snapshot else { return }
                let newHands = snapshot.documents.compactMap { doc -> SavedHand? in
                    guard let dict = doc.data()["hand"] as? [String: Any],
                          let data = try? JSONSerialization.data(withJSONObject: dict),
                          let hand = try? JSONDecoder().decode(ParsedHandHistory.self, from: data),
                          let timestamp = doc.data()["timestamp"] as? Timestamp
                    else { return nil }
                    return SavedHand(
                        id: doc.documentID,
                        hand: hand,
                        timestamp: timestamp.dateValue()
                    )
                }
                handStore.savedHands.append(contentsOf: newHands)
                lastDocument = snapshot.documents.last
                allLoaded = newHands.count < 10
            }
    }
}

// Updated HandRowView to use SavedHand
struct HandRowView: View {
    let savedHand: SavedHand

    var body: some View {
        VStack(alignment: .leading) {
            HandSummaryRow(hand: savedHand.hand)
        }
    }
} 