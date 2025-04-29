import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

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
            let avatarURL = data["avatarURL"] as? String
            print("[DEBUG] Profile avatarURL from Firestore: \(avatarURL ?? "nil")")
            DispatchQueue.main.async {
                self.currentUserProfile = UserProfile(
                    id: userId,
                    username: data["username"] as? String ?? "",
                    displayName: data["displayName"] as? String,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    favoriteGames: data["favoriteGames"] as? [String],
                    bio: data["bio"] as? String,
                    avatarURL: avatarURL,
                    location: data["location"] as? String,
                    favoriteGame: data["favoriteGame"] as? String
                )
            }
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
                createdAt: Date(),
                favoriteGames: nil,
                bio: nil,
                avatarURL: nil,
                location: nil,
                favoriteGame: nil
            )
            
            let docRef = db.collection("users").document(userId)
            try await docRef.setData([
                "id": newProfile.id,
                "username": newProfile.username,
                "displayName": newProfile.displayName ?? "",
                "createdAt": Timestamp(date: newProfile.createdAt),
            ])
            
            print("✅ Successfully created profile")
            DispatchQueue.main.async {
                self.currentUserProfile = newProfile
            }
            
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
    
    func uploadProfileImage(_ image: UIImage, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let storageRef = Storage.storage().reference().child("profile_images/\(userId).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not convert image."])) )
            return
        }
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                if let urlString = url?.absoluteString {
                    // Ensure we're using HTTPS
                    let httpsUrlString = urlString.replacingOccurrences(of: "http://", with: "https://")
                    print("[DEBUG] Firebase Storage download URL: \(httpsUrlString)")
                    completion(.success(httpsUrlString))
                } else {
                    completion(.failure(NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No URL returned."])) )
                }
            }
        }
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
