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
                    // Modern header with gradient
                    HStack {
                        Text("Home")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 0.98)),
                                Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 0.95))
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundColor(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)))
                            .padding(.horizontal, 20)
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
                        
                        LazyVStack(spacing: 16) {
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
                                    .padding(.vertical, 20)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
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
                            .frame(width: 56, height: 56)
                            .shadow(color: Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 0.3)), radius: 8, y: 4)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
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
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Header
                    HStack(spacing: 4) {
                        Text(post.username)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("·")
                            .foregroundColor(.gray)
                        
                        Text(post.createdAt.timeAgoDisplay())
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                    }
                    
                    // Post content
                    Text(post.content)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Hand post content
                    if post.postType == .hand, let hand = post.handHistory {
                        HandSummaryView(hand: hand)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                        
                        Button(action: { showingReplay = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Replay")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                            .cornerRadius(6)
                        }
                    }
                    
                    // Images
                    if let imageURLs = post.imageURLs, !imageURLs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(imageURLs, id: \.self) { url in
                                    AsyncImage(url: URL(string: url)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                                    }
                                    .frame(width: 180, height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Actions
                    HStack(spacing: 24) {
                        Button(action: toggleLike) {
                            HStack(spacing: 4) {
                                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 14))
                                    .foregroundColor(post.isLiked ? .red : .gray)
                                Text("\(post.likes)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Button(action: {}) {
                            HStack(spacing: 4) {
                                Image(systemName: "message")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                Text("\(post.comments)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                        }
                        
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
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)))
                .padding(.horizontal, 16)
                .padding(.bottom, -0.5),
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
                    HStack(spacing: 12) {
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
                        } else {
                            Circle()
                                .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userProfile.username)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("What's happening?")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Text Editor
                    TextEditor(text: $postText)
                        .focused($isTextEditorFocused)
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .frame(maxHeight: .infinity)
                        .padding()
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                    
                    // Selected Images
                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedImages, id: \.self) { image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            Button(action: {
                                                if let index = selectedImages.firstIndex(of: image) {
                                                    selectedImages.remove(at: index)
                                                }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.5))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4),
                                            alignment: .topTrailing
                                        )
                                }
                            }
                            .padding()
                        }
                    }
                    
                    // Bottom toolbar
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedItems,
                                   maxSelectionCount: 4,
                                   matching: .images) {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.system(size: 20))
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
                                .font(.system(size: 20))
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "location")
                                .foregroundColor(.gray)
                                .font(.system(size: 20))
                        }
                        
                        Spacer()
                        
                        Text("\(280 - postText.count)")
                            .foregroundColor(postText.count > 280 ? .red : .gray)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding()
                    .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 0.95)))
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
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createPost) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || postText.count > 280)
                    .foregroundColor(postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || postText.count > 280 ? .gray : .white)
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
