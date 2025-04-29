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
        
        // More detailed date logging
        if let startDateTimestamp = data["startDate"] as? Timestamp {
            self.startDate = startDateTimestamp.dateValue()
            print("📅 Session \(id) startDate: \(startDateTimestamp.dateValue())")
        } else {
            print("⚠️ No startDate timestamp for session \(id)")
            self.startDate = Date()
        }
        
        if let startTimeTimestamp = data["startTime"] as? Timestamp {
            self.startTime = startTimeTimestamp.dateValue()
            print("🕒 Session \(id) startTime: \(startTimeTimestamp.dateValue())")
        } else {
            print("⚠️ No startTime timestamp for session \(id)")
            self.startTime = Date()
        }
        
        if let endTimeTimestamp = data["endTime"] as? Timestamp {
            self.endTime = endTimeTimestamp.dateValue()
        } else {
            self.endTime = Date()
        }
        
        self.hoursPlayed = data["hoursPlayed"] as? Double ?? 0
        self.buyIn = data["buyIn"] as? Double ?? 0
        self.cashout = data["cashout"] as? Double ?? 0
        self.profit = data["profit"] as? Double ?? 0
        
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
            print("📝 Session \(id) createdAt: \(createdAtTimestamp.dateValue())")
        } else {
            self.createdAt = Date()
        }
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
        print("📱 SessionStore initialized with userId: \(userId)")
        self.userId = userId
        fetchSessions()
    }
    
    func fetchSessions() {
        print("🔍 Fetching sessions for user: \(userId)")
        db.collection("sessions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "startDate", descending: true)
            .order(by: "startTime", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching sessions: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No documents found in snapshot")
                    return
                }
                
                print("📄 Received \(documents.count) session documents")
                
                self?.sessions = documents.map { document in
                    let data = document.data()
                    print("\n🔍 Processing session: \(document.documentID)")
                    print("Raw startDate: \(String(describing: data["startDate"]))")
                    print("Raw startTime: \(String(describing: data["startTime"]))")
                    print("Profit: \(data["profit"] as? Double ?? 0)")
                    return Session(id: document.documentID, data: data)
                }
                
                print("\n✅ Final sessions array:")
                self?.sessions.forEach { session in
                    print("ID: \(session.id)")
                    print("Date: \(session.startDate)")
                    print("Profit: \(session.profit)")
                    print("---")
                }
            }
    }
    
    func addSession(_ sessionData: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection("sessions").addDocument(data: sessionData, completion: completion)
    }
    
    func deleteSession(_ sessionId: String, completion: @escaping (Error?) -> Void) {
        db.collection("sessions").document(sessionId).delete(completion: completion)
    }
} 