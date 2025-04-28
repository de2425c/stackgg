import Foundation
import FirebaseFirestore

struct Session: Identifiable, Equatable {
    let id: String
    let userId: String
    let gameType: String
    let gameName: String
    let stakes: String
    let startDate: Date
    let startTime: Date
    let endTime: Date
    let hoursPlayed: Double
    let buyIn: Double
    let cashout: Double
    let profit: Double
    let createdAt: Date
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.userId = data["userId"] as? String ?? ""
        self.gameType = data["gameType"] as? String ?? ""
        self.gameName = data["gameName"] as? String ?? ""
        self.stakes = data["stakes"] as? String ?? ""
        self.startDate = (data["startDate"] as? Timestamp)?.dateValue() ?? Date()
        self.startTime = (data["startTime"] as? Timestamp)?.dateValue() ?? Date()
        self.endTime = (data["endTime"] as? Timestamp)?.dateValue() ?? Date()
        self.hoursPlayed = data["hoursPlayed"] as? Double ?? 0
        self.buyIn = data["buyIn"] as? Double ?? 0
        self.cashout = data["cashout"] as? Double ?? 0
        self.profit = data["profit"] as? Double ?? 0
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs.id == rhs.id &&
               lhs.userId == rhs.userId &&
               lhs.gameType == rhs.gameType &&
               lhs.gameName == rhs.gameName &&
               lhs.stakes == rhs.stakes &&
               lhs.startDate == rhs.startDate &&
               lhs.startTime == rhs.startTime &&
               lhs.endTime == rhs.endTime &&
               lhs.hoursPlayed == rhs.hoursPlayed &&
               lhs.buyIn == rhs.buyIn &&
               lhs.cashout == rhs.cashout &&
               lhs.profit == rhs.profit &&
               lhs.createdAt == rhs.createdAt
    }
}

class SessionStore: ObservableObject {
    @Published var sessions: [Session] = []
    private let db = Firestore.firestore()
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
        fetchSessions()
    }
    
    func fetchSessions() {
        db.collection("sessions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "startDate", descending: true)
            .order(by: "startTime", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self?.sessions = documents.map { Session(id: $0.documentID, data: $0.data()) }
            }
    }
    
    func addSession(_ sessionData: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection("sessions").addDocument(data: sessionData, completion: completion)
    }
    
    func deleteSession(_ sessionId: String, completion: @escaping (Error?) -> Void) {
        db.collection("sessions").document(sessionId).delete(completion: completion)
    }
} 