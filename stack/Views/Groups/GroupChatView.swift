import SwiftUI
import FirebaseAuth
import PhotosUI
import Combine

// Add print statements for key lifecycle events
extension View {
    func onViewLifecycle(created: String? = nil, appeared: String? = nil, disappeared: String? = nil) -> some View {
        self
            .onAppear {
                if let msg = appeared {
                    let timestamp = Date()
                    print("VIEW LIFECYCLE [\(timestamp.formatted(date: .numeric, time: .standard))]: \(msg) appeared")
                }
            }
            .onDisappear {
                if let msg = disappeared {
                    let timestamp = Date()
                    print("VIEW LIFECYCLE [\(timestamp.formatted(date: .numeric, time: .standard))]: \(msg) disappeared")
                }
            }
            .task {
                if let msg = created {
                    let timestamp = Date()
                    print("VIEW LIFECYCLE [\(timestamp.formatted(date: .numeric, time: .standard))]: \(msg) created")
                }
            }
    }
}

struct GroupChatView: View {
    @Environment(\.dismiss) var dismiss
    private let groupService = GroupService()
    @EnvironmentObject private var handStore: HandStore
    @EnvironmentObject private var postService: PostService
    @EnvironmentObject private var userService: UserService
    @EnvironmentObject private var sessionStore: SessionStore
    
    // State for messages that we manually update from the subscription
    @State private var messages: [GroupMessage] = []
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var showingHandPicker = false
    @State private var selectedImage: UIImage?
    @State private var imagePickerItem: PhotosPickerItem?
    @State private var isLoadingMessages = false
    @State private var showingGroupInfo = false
    @State private var isSendingMessage = false
    @State private var isSendingImage = false
    @State private var error: String?
    @State private var showError = false
    @State private var viewState: ViewState = .loading
    
    // For scrolling to bottom
    @State private var scrollToBottom = false
    @State private var lastMessageId: String?
    
    // To store cancellables
    @State private var cancellables = Set<AnyCancellable>()
    
    // Debug timestamps
    @State private var viewCreatedTime = Date()
    @State private var renderStartTime = Date()
    @State private var renderEndTime = Date()
    
    let group: UserGroup
    
    // Enum to track view state
    enum ViewState {
        case loading
        case ready
        case error(String)
    }
    
    var body: some View {
        // Debug - capture render start time
        let _ = { renderStartTime = Date(); print("RENDER START: \(renderStartTime.formatted())") }()
        
        GeometryReader { geometry in
            ZStack {
                // Immediate solid background
                Color.black
                    .ignoresSafeArea()
                    .onViewLifecycle(appeared: "Black background")
                
                // Main content
                ZStack {
                    // Content based on view state
                    switch viewState {
                    case .loading:
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Loading chat...")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onViewLifecycle(appeared: "Loading state")
                        
                    case .ready:
                        VStack(spacing: 0) {
                            // Custom navigation bar
                            HStack {
                                Button(action: { dismiss() }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(12)
                                }
                                
                                Spacer()
                                
                                Text(group.name)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: { showingGroupInfo = true }) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(12)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                            .background(Color.black.opacity(0.5))
                            
                            // Chat messages
                            ScrollViewReader { scrollView in
                                ScrollView {
                                    LazyVStack(spacing: 8) {
                                        if isLoadingMessages && messages.isEmpty {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(1.5)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .padding(.vertical, 100)
                                        } else if messages.isEmpty {
                                            VStack(spacing: 16) {
                                                Image(systemName: "bubble.left.and.bubble.right")
                                                    .font(.system(size: 60))
                                                    .foregroundColor(.gray)
                                                
                                                Text("No messages yet")
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundColor(.white)
                                                
                                                Text("Start the conversation by sending a message")
                                                    .font(.system(size: 15))
                                                    .foregroundColor(.gray)
                                                    .multilineTextAlignment(.center)
                                            }
                                            .padding(.vertical, 100)
                                        } else {
                                            ForEach(messages) { message in
                                                MessageRow(message: message)
                                                    .id(message.id)
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                        
                                        // Spacer at the bottom to ensure scrolling works properly
                                        Color.clear.frame(height: 1)
                                            .id("bottomAnchor")
                                    }
                                    .padding(.top, 8)
                                }
                                .onChange(of: messages.count) { _ in
                                    withAnimation {
                                        scrollView.scrollTo("bottomAnchor", anchor: .bottom)
                                    }
                                }
                                .onAppear {
                                    withAnimation {
                                        scrollView.scrollTo("bottomAnchor", anchor: .bottom)
                                    }
                                }
                            }
                            
                            // Message input
                            VStack(spacing: 8) {
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                
                                HStack(spacing: 12) {
                                    // Image button
                                    ZStack {
                                        PhotosPicker(selection: $imagePickerItem, matching: .images) {
                                            Image(systemName: isSendingImage ? "hourglass" : "photo")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                                .frame(width: 32, height: 32)
                                                .background(Color(UIColor(red: 50/255, green: 50/255, blue: 55/255, alpha: 1.0)))
                                                .cornerRadius(16)
                                        }
                                        
                                        if isSendingImage {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.7)
                                        }
                                    }
                                    .onChange(of: imagePickerItem) { newItem in
                                        Task {
                                            do {
                                                print("IMAGE: Starting image transfer at \(Date().formatted())")
                                                
                                                guard let newItem = newItem else {
                                                    print("IMAGE: No item selected")
                                                    return
                                                }
                                                
                                                let data = try await newItem.loadTransferable(type: Data.self)
                                                
                                                guard let data = data else {
                                                    print("IMAGE: Failed to load image data")
                                                    throw NSError(domain: "ImageLoading", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load image data"])
                                                }
                                                
                                                guard let image = UIImage(data: data) else {
                                                    print("IMAGE: Failed to create UIImage from data")
                                                    throw NSError(domain: "ImageLoading", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create image from data"])
                                                }
                                                
                                                print("IMAGE: Successfully loaded image: \(image.size.width)x\(image.size.height)")
                                                
                                                // Clean up the picker item to allow selecting the same image again
                                                await MainActor.run {
                                                    imagePickerItem = nil
                                                    selectedImage = image
                                                    sendImage(image)
                                                }
                                            } catch {
                                                print("IMAGE ERROR: \(error.localizedDescription)")
                                                await MainActor.run {
                                                    self.error = "Failed to load image: \(error.localizedDescription)"
                                                    self.showError = true
                                                    imagePickerItem = nil
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Hand history button
                                    Button(action: {
                                        showingHandPicker = true
                                    }) {
                                        Image(systemName: "doc.text")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                            .background(Color(UIColor(red: 50/255, green: 50/255, blue: 55/255, alpha: 1.0)))
                                            .cornerRadius(16)
                                    }
                                    
                                    // Text input
                                    ZStack(alignment: .trailing) {
                                        TextField("Message", text: $messageText)
                                            .padding(12)
                                            .background(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)))
                                            .cornerRadius(20)
                                            .foregroundColor(.white)
                                        
                                        // Send button
                                        if !messageText.isEmpty {
                                            Button(action: sendTextMessage) {
                                                Image(systemName: isSendingMessage ? "circle" : "arrow.up.circle.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                                                    .padding(.trailing, 8)
                                                    .overlay(
                                                        Group {
                                                            if isSendingMessage {
                                                                ProgressView()
                                                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0))))
                                                                    .padding(.trailing, 8)
                                                            }
                                                        }
                                                    )
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            .background(Color(UIColor(red: 25/255, green: 25/255, blue: 30/255, alpha: 0.95)))
                        }
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 0)
                        }
                        .onViewLifecycle(appeared: "Ready state")
                        
                    case .error(let message):
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.yellow)
                            
                            Text("Error Loading Chat")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(message)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Button("Try Again") {
                                viewState = .loading
                                loadMessages()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.top, 10)
                            
                            Button("Go Back") {
                                dismiss()
                            }
                            .padding(.top, 10)
                            .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onViewLifecycle(appeared: "Error state")
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            // Track view appearance
            print("ONAPPEAR: GroupChatView appeared at \(Date().formatted()) - \(Date().timeIntervalSince(viewCreatedTime)) seconds after init")
            
            // Set up Combine subscription to groupService
            setupSubscription()
        }
        .task {
            // View was created
            viewCreatedTime = Date()
            print("TASK: GroupChatView task started at \(Date().formatted())")
            
            // Don't wait for onAppear - preload messages immediately when task starts
            await preloadMessages()
        }
        .onDisappear {
            print("ONDISAPPEAR: GroupChatView disappeared at \(Date().formatted())")
            
            // Clean up subscriptions
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
        }
        .sheet(isPresented: $showingGroupInfo) {
            GroupDetailView(group: group)
        }
        .sheet(isPresented: $showingHandPicker) {
            HandHistorySelectionView { handId in
                sendHandHistory(handId)
                showingHandPicker = false
            }
            .environmentObject(handStore)
            .environmentObject(postService)
            .environmentObject(userService)
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(error ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
        .edgesIgnoringSafeArea(.all)
        .background(Color.black)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onPreferenceChange(ViewRenderTimeKey.self) { _ in
            // Debug - capture render end time
            renderEndTime = Date()
            print("RENDER END: \(renderEndTime.formatted()) - Duration: \(renderEndTime.timeIntervalSince(renderStartTime)) seconds")
        }
        .preference(key: ViewRenderTimeKey.self, value: Date())
    }
    
    // Setup Combine subscription to observe messages
    private func setupSubscription() {
        print("SUBSCRIPTION: Setting up at \(Date().formatted())")
        
        // Setup publisher subscription for messages
        groupService.$groupMessages
            .receive(on: RunLoop.main)
            .sink { newMessages in
                print("SUBSCRIPTION: Received \(newMessages.count) messages at \(Date().formatted())")
                messages = newMessages
            }
            .store(in: &cancellables)
    }
    
    // Preload messages using Task for better async handling
    private func preloadMessages() async {
        let startTime = Date()
        print("FETCH: Starting at \(startTime.formatted())")
        isLoadingMessages = true
        
        do {
            // Use Task.sleep to simulate a delay, remove in production
            // try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Use new thread with high priority for fetching
            try await Task.detached(priority: .userInitiated) {
                let fetchStart = Date()
                
                // Start loading immediately
                try await groupService.fetchGroupMessages(groupId: group.id)
                
                let fetchEnd = Date()
            }.value
            
            let endTime = Date()
            
            // Update UI on main thread
            await MainActor.run {
                let uiStart = Date()
                
                isLoadingMessages = false
                viewState = .ready
                
                let uiEnd = Date()
            }
        } catch {
            print("FETCH ERROR: \(error.localizedDescription) at \(Date().formatted())")
            
            await MainActor.run {
                self.error = error.localizedDescription
                self.showError = true
                isLoadingMessages = false
                viewState = .error(error.localizedDescription)
            }
        }
    }
    
    private func loadMessages() {
        Task {
            await preloadMessages()
        }
    }
    
    private func sendTextMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let trimmedText = messageText
        messageText = ""
        isSendingMessage = true
        
        Task {
            do {
                try await groupService.sendTextMessage(groupId: group.id, text: trimmedText)
                await MainActor.run {
                    isSendingMessage = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.showError = true
                    isSendingMessage = false
                    // Restore the message if sending failed
                    messageText = trimmedText
                }
            }
        }
    }
    
    private func sendImage(_ image: UIImage) {
        isSendingImage = true
        print("IMAGE: Sending image to server at \(Date().formatted())")
        
        Task {
            do {
                // Add a small delay to ensure UI updates
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                try await groupService.sendImageMessage(groupId: group.id, image: image)
                print("IMAGE: Successfully sent image at \(Date().formatted())")
                
                await MainActor.run {
                    isSendingImage = false
                }
            } catch {
                print("IMAGE UPLOAD ERROR: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.error = "Failed to upload image: \(error.localizedDescription)"
                    self.showError = true
                    isSendingImage = false
                }
            }
        }
    }
    
    private func sendHandHistory(_ handId: String) {
        Task {
            do {
                try await groupService.sendHandMessage(groupId: group.id, handHistoryId: handId)
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
}

struct MessageRow: View {
    let message: GroupMessage
    
    // Check if the current user is the sender
    private var isCurrentUser: Bool {
        return message.senderId == Auth.auth().currentUser?.uid
    }
    
    // Format the timestamp
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
    
    var body: some View {
        HStack(alignment: .top) {
            if isCurrentUser {
                Spacer()
            } else {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)))
                        .frame(width: 36, height: 36)
                    
                    if let avatarURL = message.senderAvatarURL, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.trailing, 8)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Group {
                    switch message.messageType {
                    case .text:
                        if let text = message.text {
                            Text(text)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isCurrentUser ? 
                                              Color(UIColor(red: 30/255, green: 100/255, blue: 50/255, alpha: 1.0)) : 
                                              Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)))
                                )
                        }
                        
                    case .image:
                        if let imageURL = message.imageURL, let url = URL(string: imageURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                                    .frame(width: 200, height: 150)
                            }
                            .frame(maxWidth: 200, maxHeight: 150)
                            .cornerRadius(16)
                        } else {
                            // Handle different image states
                            VStack {
                                if let status = message.imageStatus {
                                    switch status {
                                    case "uploading":
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.2)
                                            .frame(width: 200, height: 150)
                                        Text("Uploading image...")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    case "error":
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.system(size: 30))
                                            .foregroundColor(.yellow)
                                            .frame(width: 200, height: 90)
                                        Text(message.errorMessage ?? "Failed to upload image")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 8)
                                    default:
                                        Image(systemName: "photo")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray)
                                            .frame(width: 200, height: 150)
                                    }
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 30))
                                        .foregroundColor(.gray)
                                        .frame(width: 200, height: 150)
                                }
                            }
                            .frame(maxWidth: 200)
                            .background(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)))
                            .cornerRadius(16)
                        }
                        
                    case .hand:
                        if let handId = message.handHistoryId {
                            // Simple hand history preview for chat
                            ChatHandPreview(handId: handId, ownerUserId: message.handOwnerUserId ?? message.senderId)
                        }
                    }
                }
                
                Text(formattedTime)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            if !isCurrentUser {
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

// A simple preview of hand history for chat messages
struct ChatHandPreview: View {
    let handId: String
    // Optional owner ID of the hand history, may be provided in the message
    var ownerUserId: String?
    
    @State private var isLoading = true
    @State private var showingDetail = false
    @State private var savedHand: SavedHand?
    @State private var loadError: String?
    @State private var showError = false
    
    @EnvironmentObject private var handStore: HandStore
    @EnvironmentObject private var postService: PostService
    @EnvironmentObject private var userService: UserService
    
    var body: some View {
        Button(action: {
            if savedHand != nil {
                showingDetail = true
            } else if loadError != nil {
                showError = true
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 200, height: 80)
                } else if let hand = savedHand {
                    // Hand preview content
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.white)
                        
                        Text("Hand History")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Show stake and profit
                    let profit = hand.hand.raw.pot.heroPnl
                    HStack {
                        Text("$\(Int(hand.hand.raw.gameInfo.smallBlind))/$\(Int(hand.hand.raw.gameInfo.bigBlind))")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Text(profit >= 0 ? "+$\(Int(profit))" : "-$\(abs(Int(profit)))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(profit >= 0 ? .green : .red)
                    }
                    
                    // Show hero cards if available
                    if let hero = hand.hand.raw.players.first(where: { $0.isHero }),
                       let cards = hero.cards {
                        HStack(spacing: 4) {
                            ForEach(cards, id: \.self) { card in
                                Text(card)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    Text("Tap to view replay")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                } else {
                    Text(loadError ?? "Hand not found")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 200, height: 80)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(12)
            .frame(width: 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)))
            )
        }
        .sheet(isPresented: $showingDetail) {
            if let hand = savedHand {
                HandReplayView(hand: hand.hand)
                    .environmentObject(postService)
                    .environmentObject(userService)
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Hand Not Available"),
                message: Text(loadError ?? "The hand history could not be loaded."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            fetchHand()
        }
    }
    
    private func fetchHand() {
        isLoading = true
        loadError = nil
        
        // Try to get the hand from the user's own collection first
        if let hand = handStore.savedHands.first(where: { $0.id == handId }) {
            savedHand = hand
            isLoading = false
            return
        }
        
        // If not found, try to fetch it as a shared hand
        Task {
            do {
                if let shared = try await handStore.fetchSharedHand(handId: handId, ownerUserId: ownerUserId) {
                    await MainActor.run {
                        savedHand = shared
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        loadError = "This hand is no longer available."
                        isLoading = false
                    }
                }
            } catch {
                print("ERROR fetching shared hand: \(error.localizedDescription)")
                await MainActor.run {
                    loadError = "Failed to load hand: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// Custom preference key to track view rendering time 
struct ViewRenderTimeKey: PreferenceKey {
    static var defaultValue: Date = Date()
    
    static func reduce(value: inout Date, nextValue: () -> Date) {
        value = nextValue()
    }
} 