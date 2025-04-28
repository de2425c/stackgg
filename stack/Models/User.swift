import Foundation
import FirebaseFirestore

struct UserProfile: Codable {
    let id: String              // Firebase Auth UID
    var username: String
    var displayName: String?
    var preferredStakes: [String]?  // e.g., ["1/2 NLH", "2/5 NLH"]
    var primaryLocation: String?    // Main casino/card room
    var createdAt: Date
    var lastActive: Date
    var totalSessions: Int
    var lifetimeEarnings: Double
    
    // Optional fields for more detailed profile
    var favoriteGames: [String]?    // e.g., ["No Limit Hold'em", "PLO"]
    var bio: String?
    var avatarURL: String?
    var location: String?
    var favoriteGame: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName
        case preferredStakes
        case primaryLocation
        case createdAt
        case lastActive
        case totalSessions
        case lifetimeEarnings
        case favoriteGames
        case bio
        case avatarURL
        case location
        case favoriteGame
    }
} 

extension Encodable {
    var dictionary: [String: Any]? {
        do {
            let data = try JSONEncoder().encode(self)
            let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return dict
        } catch {
            print("Error converting to dictionary:", error)
            return nil
        }
    }
}
