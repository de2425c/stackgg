import Foundation
import FirebaseFirestore

struct Post: Identifiable, Codable {
    @DocumentID var id: String?
    let content: String
    let userId: String
    let username: String
    let createdAt: Date
    var likes: Int
    var comments: Int
    var isLiked: Bool = false
    let profileImage: String?
    let imageURLs: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case userId
        case username
        case createdAt
        case likes
        case comments
        case profileImage
        case imageURLs
    }
    
    init(id: String, userId: String, content: String, createdAt: Date, username: String, profileImage: String? = nil, imageURLs: [String]? = nil, likes: Int = 0, comments: Int = 0) {
        self.id = id
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
        self.username = username
        self.profileImage = profileImage
        self.imageURLs = imageURLs
        self.likes = likes
        self.comments = comments
    }
    
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let userId = data["userId"] as? String,
              let content = data["content"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let username = data["username"] as? String else {
            return nil
        }
        
        self.id = document.documentID
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
        self.username = username
        self.profileImage = data["profileImage"] as? String
        self.imageURLs = data["imageURLs"] as? [String]
        self.likes = (data["likes"] as? Int) ?? 0
        self.comments = (data["comments"] as? Int) ?? 0
    }
    
    var dictionary: [String: Any] {
        return [
            "userId": userId,
            "content": content,
            "createdAt": Timestamp(date: createdAt),
            "username": username,
            "profileImage": profileImage as Any,
            "imageURLs": imageURLs as Any,
            "likes": likes,
            "comments": comments
        ]
    }
} 