import SwiftUI
import FirebaseAuth
import PhotosUI
import UIKit

struct HomePage: View {
    @State private var selectedTab: Tab = .dashboard
    let userId: String
    @State private var showingMenu = false
    @State private var showingReplay = false
    @State private var replayHand: ParsedHandHistory?
    @State private var showingSessionForm = false
    @StateObject private var sessionStore: SessionStore
    @StateObject private var handStore: HandStore
    @StateObject private var postService = PostService()
    @EnvironmentObject private var userService: UserService
    
    init(userId: String) {
        self.userId = userId
        _sessionStore = StateObject(wrappedValue: SessionStore(userId: userId))
        _handStore = StateObject(wrappedValue: HandStore(userId: userId))
        
        // Set up notification observer to switch to feed tab when a hand is shared
        setupNotificationObserver()
    }
    
    // Set up notification observer
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SwitchToFeedTab"),
            object: nil,
            queue: .main
        ) { [self] _ in
            // Switch to feed tab when notification is received
            DispatchQueue.main.async {
                selectedTab = .feed
            }
        }
    }
    
    enum Tab {
        case dashboard
        case feed
        case add
        case groups
        case profile
    }
    
    var body: some View {
        ZStack {
            // Background that excludes the tab bar central button
            ZStack {
                // Full screen material blur
                Color.black.opacity(0.5)
                    .background(.thinMaterial)
                    .ignoresSafeArea()
                
                // Cutout for the + button - positioned at center bottom
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.black.opacity(0.01)) // Nearly transparent
                            .blendMode(.destinationOut) // This creates the "hole" effect
                            .frame(width: 70, height: 70)
                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
            }
            .compositingGroup() // Ensures the blendMode works properly
            
            // Dim overlay to darken screen outside the menu
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showingMenu = false }
                }
            
            TabView(selection: $selectedTab) {
                DashboardView(userId: userId)
                    .tag(Tab.dashboard)
                
                FeedView(userId: userId)
                    .tag(Tab.feed)
                
                Color.clear // Placeholder for Add tab
                    .tag(Tab.add)
                
                GroupsView()
                    .environmentObject(userService)
                    .environmentObject(handStore)
                    .environmentObject(sessionStore)
                    .environmentObject(postService)
                    .tag(Tab.groups)
                
                ProfileScreen(userId: userId)
                    .tag(Tab.profile)
            }
            .background(Color.clear)

            CustomTabBar(
                selectedTab: $selectedTab,
                userId: userId,
                showingMenu: $showingMenu
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 0)
            .opacity(showingReplay ? 0 : 1)
            
            if showingMenu {
                AddMenuOverlay(
                    showingMenu: $showingMenu,
                    userId: userId,
                    showSessionForm: $showingSessionForm
                )
                .zIndex(1)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showingReplay) {
            if let hand = replayHand {
                HandReplayView(hand: hand)
            }
        }
        .sheet(isPresented: $showingSessionForm) {
            SessionFormView(userId: userId)
        }
        .onDisappear {
            // Remove observer when view disappears
            NotificationCenter.default.removeObserver(self)
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: HomePage.Tab
    let userId: String
    @Binding var showingMenu: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Background - Change to clear
            Color.clear
                .frame(height: 65)
                .overlay(
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Spacer(minLength: 6)
                            TabBarButton(
                                icon: "Dashboard",
                                title: "Dashboard",
                                isSelected: selectedTab == .dashboard
                            ) { selectedTab = .dashboard }
                            TabBarButton(
                                icon: "Feed",
                                title: "Feed",
                                isSelected: selectedTab == .feed
                            ) { selectedTab = .feed }
                            Spacer(minLength: 0)
                            ZStack {
                                Color.clear.frame(width: 1, height: 1)
                                AddButton(userId: userId, showingMenu: $showingMenu)
                                    .offset(y: -24)
                            }
                            .frame(width: 80, alignment: .center)
                            Spacer(minLength: 0)
                            TabBarButton(
                                icon: "Groups",
                                title: "Groups",
                                isSelected: selectedTab == .groups
                            ) { selectedTab = .groups }
                            TabBarButton(
                                icon: "Profile",
                                title: "Profile",
                                isSelected: selectedTab == .profile
                            ) { selectedTab = .profile }
                            Spacer(minLength: 6)
                        }
                        .padding(.horizontal, 0)
                        .padding(.top, 8)
                        .padding(.bottom, 22)
                    }
                )
        }
        .frame(height: 78)
        .frame(maxWidth: .infinity)
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    private var accentColor: Color {
        Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0))
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .padding(.vertical, 6)
                    .foregroundColor(isSelected ? accentColor : .gray)
                    .shadow(color: isSelected ? accentColor.opacity(0.4) : .clear, radius: isSelected ? 5 : 0)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }
}

struct AddButton: View {
    let userId: String
    @Binding var showingMenu: Bool

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showingMenu.toggle()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                    .frame(width: 60, height: 60)
                    .shadow(color: Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 0.3)), radius: 10)
                PlusIcon()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.black)
                    .rotationEffect(.degrees(showingMenu ? 45 : 0))
            }
        }
        .offset(x: 0)
    }
}

struct PlusIcon: View {
    var body: some View {
        GeometryReader { geo in
            let lineWidth: CGFloat = geo.size.width * 0.13
            let length: CGFloat = geo.size.width
            ZStack {
                RoundedRectangle(cornerRadius: lineWidth/2)
                    .frame(width: lineWidth, height: length)
                RoundedRectangle(cornerRadius: lineWidth/2)
                    .frame(width: length, height: lineWidth)
            }
        }
    }
}

struct SleekMenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 0.95)))
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.green.opacity(0.25), radius: 12, y: 4)
                        .overlay(
                            Circle()
                                .stroke(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)), lineWidth: 2)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.green.opacity(0.18), radius: 2, y: 1)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

// Break out the title view
struct HandTitleView: View {
    var body: some View {
        Text("Add Poker Hand")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.top, 12)
    }
}

// Break out the text editor
struct HandTextEditorView: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused($isFocused)
                .foregroundColor(.white)
                .font(.system(size: 15, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(16)
                .frame(minHeight: 180, maxHeight: 220)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.1, green: 0.1, blue: 0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isFocused ? 
                                Color(red: 123/255, green: 255/255, blue: 99/255) : 
                                Color(white: 0.3), 
                            lineWidth: isFocused ? 2 : 1
                        )
                )
            
            if text.isEmpty && !isFocused {
                Text("Paste your hand history here...")
                    .foregroundColor(Color.gray)
                    .font(.system(size: 15, design: .default))
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// Break out the button
struct ParseButtonView: View {
    var isLoading: Bool
    var isEmpty: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "play.card")
                        .font(.system(size: 17, weight: .semibold))
                }
                
                Text(isLoading ? "Parsing..." : "Parse Hand")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 123/255, green: 255/255, blue: 99/255),
                        Color(red: 100/255, green: 230/255, blue: 85/255)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(isEmpty || isLoading ? 0.6 : 1)
            )
            .foregroundColor(.black)
            .cornerRadius(16)
            .shadow(color: Color(red: 123/255, green: 255/255, blue: 99/255), radius: 8, y: 2)
        }
        .disabled(isEmpty || isLoading)
        .padding(.vertical, 4)
    }
}

// Break out success view
struct ParseSuccessView: View {
    let parsedHand: ParsedHandHistory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Successfully Parsed!")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 123/255, green: 255/255, blue: 99/255))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Display small blind and big blind as stakes
                    Text("Stakes: $\(parsedHand.raw.gameInfo.smallBlind)/$\(parsedHand.raw.gameInfo.bigBlind)")
                        .foregroundColor(.white)
                    
                    // Show total pot amount
                    Text("Pot: $\(String(format: "%.2f", parsedHand.raw.pot.amount))")
                        .foregroundColor(.white)
                    
                    // Display number of players
                    Text("Players: \(parsedHand.raw.players.count)")
                        .foregroundColor(.white)
                    
                    // Display hero's seat if available
                    if let hero = parsedHand.raw.players.first(where: { $0.isHero }) {
                        Text("Your Position: Seat \(hero.seat)")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color(red: 123/255, green: 255/255, blue: 99/255))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 123/255, green: 255/255, blue: 99/255), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .transition(.opacity)
    }
}

// Simplified AddHandView that uses the components
struct AddHandView: View {
    let userId: String
    var onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var handStore = HandStore(userId: "")
    @State private var handText = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var parsedHand: ParsedHandHistory?
    @State private var showingSuccess = false
    @FocusState private var isFocused: Bool

    init(userId: String, onDismiss: @escaping () -> Void) {
        self.userId = userId
        self.onDismiss = onDismiss
        _handStore = StateObject(wrappedValue: HandStore(userId: userId))
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                HandTitleView()
                
                VStack(spacing: 16) {
                    HandTextEditorView(text: $handText, isFocused: $isFocused)
                    
                    ParseButtonView(
                        isLoading: isLoading,
                        isEmpty: handText.isEmpty,
                        action: parseHand
                    )
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.1))
                        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
                )
                .padding(.horizontal, 16)
                
                if let parsedHand = parsedHand {
                    ParseSuccessView(parsedHand: parsedHand)
                }
                
                Spacer()
                
                // Close button
                Button(action: { onDismiss(); dismiss() }) {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.18))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8)
                }
                .padding(.bottom, 16)
            }
            .padding(.top, 10)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func parseHand() {
        isLoading = true
        Task {
            do {
                let parsed = try await HandParserService.shared.parseHand(description: handText)
                self.parsedHand = parsed
                
                // Show verification view instead of immediately saving
                DispatchQueue.main.async {
                    showingSuccess = true
                    self.showVerificationView(originalText: handText, parsedHand: parsed)
                }
            } catch let error as HandParserError {
                errorMessage = error.message
                showingError = true
            } catch {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                showingError = true
            }
            isLoading = false
        }
    }
    
    private func showVerificationView(originalText: String, parsedHand: ParsedHandHistory) {
        // Create and present the verification view
        let verificationView = HandVerificationView(
            originalText: originalText,
            parsedHand: parsedHand, 
            onComplete: { result in
                if result {
                    // Save the hand if verification was successful
                    Task {
                        try? await handStore.saveHand(parsedHand)
                        DispatchQueue.main.async {
                            onDismiss()
                            dismiss()
                        }
                    }
                } else {
                    // Just dismiss if canceled
                    DispatchQueue.main.async {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        )
        
        // Present the verification view as a sheet using modern API
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Get the topmost presented controller
        var topController = rootVC
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        let hostingController = UIHostingController(rootView: verificationView)
        topController.present(hostingController, animated: true)
    }
}

struct ProfileScreen: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var authViewModel: AuthViewModel
    let userId: String
    @State private var showEdit = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Apply new background view
                AppBackgroundView()
                
                VStack(spacing: 0) {
                    // STACK logo at the top
                    HStack {
                        Spacer()
                        Text("STACK")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        
                        // Add sign out button to top right
                        Button(action: signOut) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 0.7)))
                                )
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 0)
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer(minLength: 0)
                    if let profile = userService.currentUserProfile {
                        VStack(spacing: 18) {
                            ZStack {
                                Circle()
                                    // Change background to clear
                                    .fill(Color.clear)
                                    .frame(width: 120, height: 120)
                                    .shadow(color: Color.green.opacity(0.18), radius: 12, y: 4)
                                if let url = profile.avatarURL, let imageURL = URL(string: url) {
                                    ProfileImageView(url: imageURL)
                                        .frame(width: 110, height: 110)
                                        .clipShape(Circle())
                                        .id(profile.avatarURL)
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 110, height: 110)
                                        .foregroundColor(Color.green.opacity(0.5))
                                }
                            }
                            .padding(.bottom, 8)
                            
                            VStack(spacing: 6) {
                                if let displayName = profile.displayName, !displayName.isEmpty {
                                    Text(displayName)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                
                                Text("@\(profile.username)")
                                    .font(.system(size: displayNameVisible(profile) ? 18 : 28, weight: displayNameVisible(profile) ? .medium : .bold, design: .rounded))
                                    .foregroundColor(.gray)
                                    
                                if let bio = profile.bio, !bio.isEmpty {
                                    Text(bio)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.85))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                        .padding(.top, 12)
                                }
                            }
                            
                            HStack(spacing: 32) {
                                NavigationLink(destination: FollowListView(userId: userId, listType: .followers)) {
                                    VStack(spacing: 8) {
                                        Text("\(profile.followersCount)")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Followers")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                NavigationLink(destination: FollowListView(userId: userId, listType: .following)) {
                                    VStack(spacing: 8) {
                                        Text("\(profile.followingCount)")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Following")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.top, 12)
                            
                            if let game = profile.favoriteGame {
                                Text("Favorite Game: \(game)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(UIColor(red: 40/255, green: 40/255, blue: 45/255, alpha: 1.0)))
                                    )
                            }
                            
                            // Edit Profile button
                            Button(action: { showEdit = true }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("Edit Profile")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 32)
                                .background(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                                .cornerRadius(22)
                                .shadow(color: Color.green.opacity(0.18), radius: 6, y: 2)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        // Change background to clear
                        .background(
                            RoundedRectangle(cornerRadius: 32)
                                .fill(Color.clear)
                                .shadow(color: .black.opacity(0.18), radius: 16, y: 4)
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 0)
                    } else {
                        ProgressView().onAppear {
                            Task { try? await userService.fetchUserProfile() }
                        }
                    }
                    Spacer()
                }
            }
            .sheet(isPresented: $showEdit) {
                if let profile = userService.currentUserProfile {
                    ProfileEditView(profile: profile) { updated in
                        Task { try? await userService.updateUserProfile(updated.dictionary ?? [:]) }
                        showEdit = false
                        Task { try? await userService.fetchUserProfile() }
                    }
                    .environmentObject(userService)
                }
            }
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .navigationTitle("")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // Helper function to check if display name is visible
    private func displayNameVisible(_ profile: UserProfile) -> Bool {
        return profile.displayName != nil && !profile.displayName!.isEmpty
    }
    
    private func signOut() {
        do {
            try Auth.auth().signOut()
            userService.currentUserProfile = nil // Clear the profile before state change
            authViewModel.checkAuthState()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

struct ProfileEditView: View {
    @State var profile: UserProfile
    var onSave: (UserProfile) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userService: UserService
    let gameOptions = ["NLH", "PLO", "Stud8", "Omaha", "Razz"]
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var imagePickerItem: PhotosPickerItem? = nil
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Display Name", text: Binding(
                        get: { profile.displayName ?? "" },
                        set: { profile.displayName = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.system(size: 16))
                    
                    TextField("Username", text: $profile.username)
                        .font(.system(size: 16))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Bio")) {
                    TextEditor(text: Binding(
                        get: { profile.bio ?? "" },
                        set: { profile.bio = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.system(size: 16))
                    .frame(height: 80)
                }
                
                Section(header: Text("Profile Picture")) {
                    HStack {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else if let url = profile.avatarURL, let imageURL = URL(string: url) {
                            ProfileImageView(url: imageURL)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            Circle().fill(Color.gray).frame(width: 80, height: 80)
                        }
                        Spacer()
                        
                        PhotosPicker(selection: $imagePickerItem, matching: .images) {
                            Text("Select Image")
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                                .cornerRadius(8)
                        }
                        .onChange(of: imagePickerItem) { newItem in
                            guard let item = newItem else { return }
                            Task {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    DispatchQueue.main.async {
                                        selectedImage = image
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Favorite Game")) {
                    Picker("Game", selection: Binding(
                        get: { profile.favoriteGame ?? "NLH" },
                        set: { profile.favoriteGame = $0 }
                    )) {
                        ForEach(gameOptions, id: \.self) { game in
                            Text(game).tag(game)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                if let uploadError = uploadError {
                    Text(uploadError).foregroundColor(.red)
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isUploading ? "Saving..." : "Save") {
                        if let selectedImage = selectedImage {
                            isUploading = true
                            userService.uploadProfileImage(selectedImage, userId: profile.id) { result in
                                DispatchQueue.main.async {
                                    isUploading = false
                                    switch result {
                                    case .success(let urlString):
                                        var updatedProfile = profile
                                        updatedProfile.avatarURL = urlString
                                        onSave(updatedProfile)
                                        dismiss()
                                    case .failure(let error):
                                        uploadError = "Image upload error: \(error.localizedDescription)"
                                    }
                                }
                            }
                        } else {
                            onSave(profile)
                            dismiss()
                        }
                    }.disabled(isUploading)
                }
            }
        }
    }
}

struct AddMenuOverlay: View {
    @Binding var showingMenu: Bool
    let userId: String
    @State private var showHandInput = false
    @Binding var showSessionForm: Bool

    var body: some View {
        ZStack {
            // Background that excludes the tab bar central button
            ZStack {
                // Full screen material blur
                Color.black.opacity(0.5)
                    .background(.thinMaterial)
                    .ignoresSafeArea()
                
                // Cutout for the + button - positioned at center bottom
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.black.opacity(0.01)) // Nearly transparent
                            .blendMode(.destinationOut) // This creates the "hole" effect
                            .frame(width: 70, height: 70)
                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
            }
            .compositingGroup() // Ensures the blendMode works properly
            
            // Dim overlay to darken screen outside the menu
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showingMenu = false }
                }
            
            // Actual menu content
            GeometryReader { geo in
                VStack {
                    Spacer()
                    VStack(spacing: 32) {
                        SleekMenuButton(
                            icon: "clock.arrow.circlepath",
                            title: "Past Session",
                            action: {
                                withAnimation(nil) {
                                    showSessionForm = true
                                    showingMenu = false
                                }
                            }
                        )
                        SleekMenuButton(
                            icon: "clock",
                            title: "Live Session",
                            action: { showingMenu = false }
                        )
                        SleekMenuButton(
                            icon: "doc.text",
                            title: "Add Hand",
                            action: { showHandInput = true }
                        )
                        
                        // Spacer to push content up
                        Spacer()
                            .frame(height: geo.size.height * 0.15)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            }
            
            // Invisible button directly over the + button to handle taps
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation { showingMenu = false }
                    }) {
                        Color.clear
                            .frame(width: 70, height: 70)
                    }
                    Spacer()
                }
                .padding(.bottom, 20)
            }
        }
        .transition(.opacity)
        .sheet(isPresented: $showHandInput) {
            AddHandView(userId: userId, onDismiss: { showHandInput = false; showingMenu = false })
        }
    }
} 
