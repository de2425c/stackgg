import Foundation
import FirebaseFirestore
import FirebaseStorage

class PostService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var lastDocument: DocumentSnapshot?
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let postsPerPage = 10
    
    func fetchPosts() async throws {
        await MainActor.run {
            isLoading = true
        }
        defer { 
            Task { @MainActor in
                isLoading = false
            }
        }
        
        let query = db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: postsPerPage)
        
        let snapshot = try await query.getDocuments()
        lastDocument = snapshot.documents.last
        
        let newPosts = try snapshot.documents.compactMap { document in
            var post = try document.data(as: Post.self)
            post.id = document.documentID
            return post
        }
        
        await MainActor.run {
            posts = newPosts
        }
    }
    
    func fetchMorePosts() async throws {
        guard let lastDocument = lastDocument, !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
        }
        defer { 
            Task { @MainActor in
                isLoading = false
            }
        }
        
        let query = db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: postsPerPage)
            .start(afterDocument: lastDocument)
        
        let snapshot = try await query.getDocuments()
        self.lastDocument = snapshot.documents.last
        
        let newPosts = try snapshot.documents.compactMap { document -> Post? in
            var post = try document.data(as: Post.self)
            post.id = document.documentID
            return post
        }
        
        await MainActor.run {
            posts.append(contentsOf: newPosts)
        }
    }
    
    func uploadImage(_ image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not convert image to data"])
        }
        
        let filename = "\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("post_images/\(filename)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    func createPost(content: String, userId: String, username: String, profileImage: String?, images: [UIImage]? = nil) async throws {
        let documentRef = db.collection("posts").document()
        
        var imageURLs: [String]? = nil
        if let images = images {
            imageURLs = try await withThrowingTaskGroup(of: String.self) { group in
                for image in images {
                    group.addTask {
                        try await self.uploadImage(image)
                    }
                }
                return try await group.reduce(into: []) { $0.append($1) }
            }
        }
        
        let post = Post(
            id: documentRef.documentID,
            userId: userId,
            content: content,
            createdAt: Date(),
            username: username,
            profileImage: profileImage,
            imageURLs: imageURLs,
            likes: 0,
            comments: 0,
            postType: .text
        )
        
        try await documentRef.setData(from: post)
        
        await MainActor.run {
            posts.insert(post, at: 0)
        }
    }
    
    func createHandPost(content: String, userId: String, username: String, profileImage: String?, hand: ParsedHandHistory) async throws {
        let documentRef = db.collection("posts").document()
        
        let post = Post(
            id: documentRef.documentID,
            userId: userId,
            content: content,
            createdAt: Date(),
            username: username,
            profileImage: profileImage,
            imageURLs: nil,
            likes: 0,
            comments: 0,
            postType: .hand,
            handHistory: hand
        )
        
        try await documentRef.setData(from: post)
        
        await MainActor.run {
            posts.insert(post, at: 0)
        }
    }
    
    func toggleLike(postId: String, userId: String) async throws {
        let postRef = db.collection("posts").document(postId)
        let likeRef = postRef.collection("likes").document(userId)
        
        let document = try await likeRef.getDocument()
        if document.exists {
            // Unlike
            try await likeRef.delete()
            try await postRef.updateData(["likes": FieldValue.increment(Int64(-1))])
            await MainActor.run {
                if let index = posts.firstIndex(where: { $0.id == postId }) {
                    posts[index].likes -= 1
                    posts[index].isLiked = false
                }
            }
        } else {
            // Like
            try await likeRef.setData(["timestamp": FieldValue.serverTimestamp()])
            try await postRef.updateData(["likes": FieldValue.increment(Int64(1))])
            await MainActor.run {
                if let index = posts.firstIndex(where: { $0.id == postId }) {
                    posts[index].likes += 1
                    posts[index].isLiked = true
                }
            }
        }
    }
    
    func deletePost(postId: String) async throws {
        try await db.collection("posts").document(postId).delete()
        await MainActor.run {
            posts.removeAll { $0.id == postId }
        }
    }
} 