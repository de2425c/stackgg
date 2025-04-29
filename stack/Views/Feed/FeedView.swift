import SwiftUI
import PhotosUI
import FirebaseStorage

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
                    // Stack Logo Header
                    HStack {
                        Image("stack_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 40)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 0.95)))
                    
                    ScrollView {
                        RefreshControl(isRefreshing: $isRefreshing) {
                            Task {
                                try? await postService.fetchPosts()
                                isRefreshing = false
                            }
                        }
                        
                        LazyVStack(spacing: 0) {
                            ForEach(postService.posts) { post in
                                PostRow(post: post)
                                    .environmentObject(postService)
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
                                    .padding()
                            }
                        }
                    }
                }
                .background(Color(UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0)))
                
                // Floating Action Button for Post
                Button(action: { showingNewPost = true }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingNewPost) {
            if let profile = userService.currentUserProfile {
                NewPostView(userId: userId, userProfile: profile, postService: postService)
            }
        }
        .onAppear {
            Task {
                try? await postService.fetchPosts()
            }
        }
    }
}

struct PostRow: View {
    let post: Post
    @State private var isLiked = false
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var postService: PostService
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    // Profile Picture
                    if let profileImage = post.profileImage {
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
                        // Header
                        HStack(spacing: 4) {
                            Text(post.username)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("·")
                                .foregroundColor(.gray)
                            
                            Text(post.createdAt.timeAgoDisplay())
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        // Content
                        Text(post.content)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .padding(.vertical, 4)
                        
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
                                                .fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(width: 200, height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // Interaction buttons
                        HStack(spacing: 24) {
                            Button(action: { toggleLike() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .foregroundColor(isLiked ? .red : .gray)
                                        .font(.system(size: 16))
                                    Text("\(post.likes)")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))
                                }
                            }
                            
                            Button(action: {}) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble.right")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                    Text("\(post.comments)")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))
                                }
                            }
                            
                            Button(action: {}) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    Menu {
                        if post.userId == userService.currentUserProfile?.id {
                            Button(role: .destructive, action: { showDeleteAlert = true }) {
                                Label("Delete Post", systemImage: "trash")
                            }
                        }
                        Button(action: {}) {
                            Label("Report", systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                }
                .padding()
            }
            .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 0.5)))
            
            Divider()
                .frame(height: 8)
                .background(Color(UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0)))
        }
        .alert("Delete Post", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .onAppear {
            isLiked = post.isLiked
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
        guard let postId = post.id, let userId = userService.currentUserProfile?.id else { return }
        Task {
            do {
                try await postService.toggleLike(postId: postId, userId: userId)
                isLiked.toggle()
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
