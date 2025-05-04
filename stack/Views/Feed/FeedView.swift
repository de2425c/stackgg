import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore

struct FeedView: View {
    @StateObject private var postService = PostService()
    @EnvironmentObject var userService: UserService
    @State private var showingNewPost = false
    @State private var isRefreshing = false
    @State private var showingDiscoverUsers = false
    let userId: String
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                AppBackgroundView()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Button(action: {
                            // Action for profile image tap, e.g., navigate to profile
                        }) {
                            if let avatarURL = userService.currentUserProfile?.avatarURL {
                                AsyncImage(url: URL(string: avatarURL)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.gray)
                                                .font(.system(size: 18))
                                        )
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 18))
                                    )
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Action for notification bell tap
                        }) {
                            Image(systemName: "bell")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    
                    ScrollView {
                        RefreshControl(isRefreshing: $isRefreshing) {
                            Task {
                                try? await postService.fetchPosts()
                                isRefreshing = false
                            }
                        }
                        
                        if postService.posts.isEmpty && !postService.isLoading {
                            VStack(spacing: 24) {
                                Spacer()
                                    .frame(height: 40)
                                
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 0.8)))
                                
                                Text("Your feed is empty")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Create your first post or follow other players to see their content here.")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                
                                Button(action: {
                                    if let profile = userService.currentUserProfile {
                                        navigateToFollowSuggestions()
                                    }
                                }) {
                                    Text("Discover Players")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                                        )
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(postService.posts) { post in
                                    PostRow(post: post)
                                        .onAppear {
                                            if post.id == postService.posts.last?.id {
                                                Task {
                                                    try? await postService.fetchMorePosts()
                                                }
                                            }
                                        }
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                }
                                
                                if postService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0))))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 24)
                                }
                            }
                        }
                        
                        Spacer(minLength: 80)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            Task {
                try? await postService.fetchPosts()
            }
        }
        .sheet(isPresented: $showingDiscoverUsers, onDismiss: {
            Task {
                try? await postService.fetchPosts()
            }
        }) {
            DiscoverUsersView(userId: userId)
        }
        .environmentObject(postService)
    }
    
    private func navigateToFollowSuggestions() {
        showingDiscoverUsers = true
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
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    if let profileImage = post.profileImage {
                        AsyncImage(url: URL(string: profileImage)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 40, height: 40)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(post.displayName ?? post.username)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("@\(post.username)")
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
                        
                        Text(post.createdAt.timeAgoDisplay())
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(post.content)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineSpacing(5)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 50)
                    
                    if post.postType == .hand, let hand = post.handHistory {
                        HandSummaryView(hand: hand, onReplayTap: {
                            showingReplay = true
                        })
                            .padding(.vertical, 10)
                            .padding(.leading, 50)
                    }
                    
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
                        .padding(.leading, 50)
                    }
                    
                    HStack(spacing: 36) {
                        Button(action: toggleLike) {
                            HStack(spacing: 8) {
                                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 16))
                                    .foregroundColor(post.isLiked ? .red : .gray)
                                Text("\(post.likes)")
                                    .font(.system(size: 14))
                                    .foregroundColor(post.isLiked ? .red : .gray)
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
                    .padding(.leading, 50)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.clear)
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
                Color(UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
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
                            Text(userProfile.displayName ?? userProfile.username)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("@\(userProfile.username)")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    
                    TextEditor(text: $postText)
                        .focused($isTextEditorFocused)
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                    
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
                    .background(Color(UIColor(red: 20/255, green: 20/255, blue: 25/255, alpha: 0.8)))
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
                    displayName: userProfile.displayName,
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

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
} 
