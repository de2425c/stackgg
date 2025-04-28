import Foundation
import FirebaseFirestore
import FirebaseAuth

class UserService: ObservableObject {
    private let db = Firestore.firestore()
    @Published var currentUserProfile: UserProfile?
    
    func fetchUserProfile() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⛔️ fetchUserProfile: No authenticated user")
            throw UserServiceError.notAuthenticated
        }
        
        print("🔍 Fetching profile for user: \(userId)")
        
        do {
            let document = try await db.collection("users")
                .document(userId)
                .getDocument()
            
            print("📄 Document exists: \(document.exists)")
            
            if !document.exists {
                print("⚠️ No profile document found")
                throw UserServiceError.profileNotFound
            }
            
            guard let data = document.data() else {
                print("⚠️ Document exists but no data")
                throw UserServiceError.invalidData
            }
            
            print("✅ Successfully fetched profile data")
            self.currentUserProfile = UserProfile(
                id: userId,
                username: data["username"] as? String ?? "",
                displayName: data["displayName"] as? String,
                preferredStakes: nil,
                primaryLocation: nil,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                lastActive: (data["lastActive"] as? Timestamp)?.dateValue() ?? Date(),
                totalSessions: data["totalSessions"] as? Int ?? 0,
                lifetimeEarnings: data["lifetimeEarnings"] as? Double ?? 0
            )
        } catch {
            print("❌ Error fetching profile: \(error)")
            throw error
        }
    }
    
    func createUserProfile(username: String, displayName: String?) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⛔️ createUserProfile: No authenticated user")
            throw UserServiceError.notAuthenticated
        }
        
        print("📝 Creating profile for user: \(userId)")
        
        // Check if username is already taken
        do {
            let querySnapshot = try await db.collection("users")
                .whereField("username", isEqualTo: username)
                .getDocuments()
            
            if !querySnapshot.documents.isEmpty {
                print("⚠️ Username already exists")
                throw UserServiceError.usernameAlreadyExists
            }
            
            let newProfile = UserProfile(
                id: userId,
                username: username,
                displayName: displayName,
                preferredStakes: nil,
                primaryLocation: nil,
                createdAt: Date(),
                lastActive: Date(),
                totalSessions: 0,
                lifetimeEarnings: 0
            )
            
            let docRef = db.collection("users").document(userId)
            try await docRef.setData([
                "id": newProfile.id,
                "username": newProfile.username,
                "displayName": newProfile.displayName ?? "",
                "createdAt": Timestamp(date: newProfile.createdAt),
                "lastActive": Timestamp(date: newProfile.lastActive),
                "totalSessions": newProfile.totalSessions,
                "lifetimeEarnings": newProfile.lifetimeEarnings
            ])
            
            print("✅ Successfully created profile")
            self.currentUserProfile = newProfile
            
        } catch let firestoreError as NSError {
            print("❌ Firestore error: \(firestoreError.localizedDescription)")
            print("❌ Error code: \(firestoreError.code)")
            print("❌ Error domain: \(firestoreError.domain)")
            throw UserServiceError.from(firestoreError)
        }
    }
    
    func updateUserProfile(_ updates: [String: Any]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw UserServiceError.notAuthenticated
        }
        
        try await db.collection("users").document(userId).updateData(updates)
        try await fetchUserProfile() // Refresh the local profile
    }
}

enum UserServiceError: Error, CustomStringConvertible {
    case notAuthenticated
    case profileNotFound
    case invalidData
    case usernameAlreadyExists
    case permissionDenied
    case serverError
    case unknown
    
    var description: String {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .profileNotFound:
            return "Profile not found"
        case .invalidData:
            return "Invalid data"
        case .usernameAlreadyExists:
            return "Username already exists"
        case .permissionDenied:
            return "Permission denied"
        case .serverError:
            return "Server error"
        case .unknown:
            return "Unknown error"
        }
    }
    
    var message: String {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to perform this action"
        case .profileNotFound:
            return "User profile not found"
        case .invalidData:
            return "Invalid profile data"
        case .usernameAlreadyExists:
            return "This username is already taken"
        case .permissionDenied:
            return "You don't have permission to access this data"
        case .serverError:
            return "A server error occurred"
        case .unknown:
            return "An unknown error occurred"
        }
    }
    
    static func from(_ error: NSError) -> UserServiceError {
        if error.domain == FirestoreErrorDomain {
            switch error.code {
            case 7: // Permission Denied
                return .permissionDenied
            case 13: // Internal Error
                return .serverError
            default:
                return .unknown
            }
        }
        return .unknown
    }
} 
