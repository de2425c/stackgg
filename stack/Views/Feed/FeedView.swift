import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore

struct FeedView: View {
    @StateObject private var postService = PostService()
    @EnvironmentObject var userService: UserService
    @State private var showingNewPost = false
    @State private var isRefreshing = false
    let userId: String
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Modern header with gradient - more Twitter-like
                    HStack {
                        Text("Home")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .background(
                        Color(UIColor(red: 20/255, green: 20/255, blue: 25/255, alpha: 0.98))
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundColor(Color(UIColor(red: 50/255, green: 50/255, blue: 55/255, alpha: 1.0)))
                            .padding(.bottom, -0.5),
                        alignment: .bottom
                    )
                    
                    ScrollView {
                        RefreshControl(isRefreshing: $isRefreshing) {
                            Task {
                                try? await postService.fetchPosts()
                                isRefreshing = false
                            }
                        }
                        
                        LazyVStack(spacing: 1) {
                            ForEach(postService.posts) { post in
                                PostRow(post: post)
                                    .onAppear {
                                        if post.id == postService.posts.last?.id {
                                            Task {
                                                try? await postService.fetchMorePosts()
                                            }
                                        }
                                    }
                            }
                            
                            if postService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0))))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 24)
                            }
                        }
                    }
                }
                .background(Color(UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0)))
                
                // Modern floating action button with gradient
                Button(action: { showingNewPost = true }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)),
                                        Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 0.8))
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 58, height: 58)
                            .shadow(color: Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 0.3)), radius: 10, y: 5)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingNewPost) {
            if let profile = userService.currentUserProfile {
                NewPostView(userId: userId, userProfile: profile, postService: postService)
                    .environmentObject(postService)
                    .environmentObject(userService)
            }
        }
        .onAppear {
            Task {
                try? await postService.fetchPosts()
            }
        }
        .environmentObject(postService)
    }
}

struct PostRow: View {
    let post: Post
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var userService: UserService
    @State private var showingDeleteAlert = false
    @State private var showingReplay = false
    
    private var isCurrentUser: Bool {
        post.userId == userService.currentUserProfile?.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    // Profile image
                    if let profileImage = post.profileImage {
                        AsyncImage(url: URL(string: profileImage)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    } else {
                        // Empty space if no profile image to maintain consistent layout
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 48, height: 48)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        // Header
                        HStack(spacing: 6) {
                            Text(post.username)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("·")
                                .foregroundColor(.gray)
                            
                            Text(post.createdAt.timeAgoDisplay())
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                                
                            Spacer()
                            
                            if isCurrentUser {
                                Menu {
                                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .padding(4)
                                }
                            }
                        }
                    }
                }
                
                // Post content - kept outside the HStack to allow full width
                VStack(alignment: .leading, spacing: 8) {
                    Text(post.content)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineSpacing(5)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 60) // Align with the content next to profile image
                    
                    // Hand post content
                    if post.postType == .hand, let hand = post.handHistory {
                        HandSummaryView(hand: hand, onReplayTap: {
                            showingReplay = true
                        })
                            .padding(.vertical, 10)
                            .padding(.leading, 60) // Align with the content next to profile image
                    }
                    
                    // Images - Full width for better display
                    if let imageURLs = post.imageURLs, !imageURLs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(imageURLs, id: \.self) { url in
                                    AsyncImage(url: URL(string: url)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                                    }
                                    .frame(width: 240, height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.leading, 60) // Align with the content next to profile image
                    }
                    
                    // Actions
                    HStack(spacing: 36) {
                        Button(action: toggleLike) {
                            HStack(spacing: 8) {
                                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 16))
                                    .foregroundColor(post.isLiked ? .red : .gray)
                                Text("\(post.likes)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Button(action: {}) {
                            HStack(spacing: 8) {
                                Image(systemName: "message")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                Text("\(post.comments)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.leading, 60) // Align with the content next to profile image
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(UIColor(red: 20/255, green: 20/255, blue: 25/255, alpha: 1.0)))
        // Clear separator between posts
        .overlay(
            Rectangle()
                .frame(height: 6)
                .foregroundColor(Color(UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0)))
                .padding(.horizontal, 0),
            alignment: .bottom
        )
        .alert("Delete Post", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .sheet(isPresented: $showingReplay) {
            if let hand = post.handHistory {
                HandReplayView(hand: hand)
                    .environmentObject(postService)
                    .environmentObject(userService)
            }
        }
    }
    
    private func deletePost() {
        guard let postId = post.id else { return }
        Task {
            do {
                try await postService.deletePost(postId: postId)
            } catch {
                print("Error deleting post: \(error)")
            }
        }
    }
    
    private func toggleLike() {
        guard let postId = post.id,
              let userId = userService.currentUserProfile?.id else { return }
        Task {
            do {
                try await postService.toggleLike(postId: postId, userId: userId)
            } catch {
                print("Error toggling like: \(error)")
            }
        }
    }
}

struct NewPostView: View {
    let userId: String
    let userProfile: UserProfile
    @ObservedObject var postService: PostService
    @Environment(\.dismiss) var dismiss
    @State private var postText = ""
    @State private var isLoading = false
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0)).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 16) {
                        if let profileImage = userProfile.avatarURL {
                            AsyncImage(url: URL(string: profileImage)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 2)
                        } else {
                            Circle()
                                .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 2)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(userProfile.username)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Text("What's happening?")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    
                    // Text Editor
                    TextEditor(text: $postText)
                        .focused($isTextEditorFocused)
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                    
                    // Selected Images
                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(selectedImages, id: \.self) { image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .shadow(color: .black.opacity(0.2), radius: 2)
                                        .overlay(
                                            Button(action: {
                                                if let index = selectedImages.firstIndex(of: image) {
                                                    selectedImages.remove(at: index)
                                                }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .padding(6),
                                            alignment: .topTrailing
                                        )
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                        }
                    }
                    
                    // Bottom toolbar
                    HStack(spacing: 20) {
                        PhotosPicker(selection: $selectedItems,
                                   maxSelectionCount: 4,
                                   matching: .images) {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.system(size: 22))
                        }
                        .onChange(of: selectedItems) { newItems in
                            Task {
                                selectedImages.removeAll()
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        selectedImages.append(image)
                                    }
                                }
                            }
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "video")
                                .foregroundColor(.gray)
                                .font(.system(size: 22))
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "location")
                                .foregroundColor(.gray)
                                .font(.system(size: 22))
                        }
                        
                        Spacer()
                        
                        Text("\(280 - postText.count)")
                            .foregroundColor(postText.count > 280 ? .red : .gray)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color(UIColor(red: 20/255, green: 20/255, blue: 25/255, alpha: 0.95)))
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .medium))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createPost) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Post")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .disabled(postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || postText.count > 280)
                    .foregroundColor(postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || postText.count > 280 ? .gray : Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || postText.count > 280 
                            ? Color.clear 
                            : Color(UIColor(red: 20/255, green: 50/255, blue: 30/255, alpha: 0.3))
                    )
                    .cornerRadius(16)
                }
            }
        }
        .onAppear {
            isTextEditorFocused = true
        }
    }
    
    private func createPost() {
        guard !postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        
        Task {
            do {
                try await postService.createPost(
                    content: postText,
                    userId: userId,
                    username: userProfile.username,
                    profileImage: userProfile.avatarURL,
                    images: selectedImages.isEmpty ? nil : selectedImages
                )
                try await postService.fetchPosts()
                DispatchQueue.main.async {
                    dismiss()
                }
            } catch {
                print("Error creating post: \(error)")
            }
            isLoading = false
        }
    }
}

// Helper for time ago display
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
} 
