import SwiftUI
import FirebaseAuth
import PhotosUI

struct HomePage: View {
    @State private var selectedTab: Tab = .dashboard
    let userId: String
    @State private var showingMenu = false
    @State private var showingReplay = false
    @State private var replayHand: ParsedHandHistory?
    @State private var showingSessionForm = false
    @StateObject private var sessionStore: SessionStore
    @StateObject private var handStore: HandStore
    
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

struct HandInputView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var handStore: HandStore
    @State private var handText = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var parsedHand: ParsedHandHistory?
    @State private var showingSuccess = false
    
    init(userId: String) {
        _handStore = StateObject(wrappedValue: HandStore(userId: userId))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0))
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    TextEditor(text: $handText)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    Button(action: parseHand) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Text("Parse Hand")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0))
                            .opacity(handText.isEmpty || isLoading ? 0.5 : 1)
                    )
                    .foregroundColor(.black)
                    .cornerRadius(12)
                    .disabled(handText.isEmpty || isLoading)
                    
                    if let parsedHand = parsedHand {
                        ScrollView {
                            Text(String(describing: parsedHand))
                                .foregroundColor(.black)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                        }
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Add Hand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
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
                
                // Save the hand to Firebase
                try await handStore.saveHand(parsed)
                
                DispatchQueue.main.async {
                    showingSuccess = true
                    // Dismiss the view after successful save
                    dismiss()
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
}

struct GroupsView: View {
    var body: some View {
        ZStack {
            // Add proper background color
            Color(UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0))
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("GROUPS")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 24)
                
                Spacer()
                
                Text("Groups Coming Soon")
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .medium))
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
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
                    Text("STACK")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.white)
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
                    Button(action: signOut) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.red.opacity(0.85))
                        )
                        .padding(.horizontal, 32)
                        .padding(.bottom, 36)
                        .shadow(color: .red.opacity(0.18), radius: 8, y: 2)
                    }
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
            HandInputViewSleek(userId: userId) {
                showHandInput = false
                showingMenu = false
            }
        }
    }
}

// Sleek, modern HandInputView
struct HandInputViewSleek: View {
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
            // Change background to clear
            Color.clear.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Add Poker Hand")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(white: 0.92))
                    .padding(.top, 12)
                VStack(spacing: 0) {
                    TextEditor(text: $handText)
                        .focused($isFocused)
                        .foregroundColor(Color(white: 0.85))
                        .font(.system(size: 16, design: .monospaced))
                        .frame(minHeight: 140, maxHeight: 180)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                // Change background to clear
                                .fill(Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isFocused ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 0.9)) : Color.clear, lineWidth: 1.5)
                        )
                        .animation(.easeInOut(duration: 0.2), value: isFocused)
                        .padding(.bottom, 10)
                    Button(action: parseHand) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0))))
                        } else {
                            Text("Parse Hand")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: handText.isEmpty || isLoading ? 0.5 : 1))
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.green.opacity(0.10), radius: 6, y: 1)
                    .disabled(handText.isEmpty || isLoading)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        // Change background to clear
                        .fill(Color.clear)
                )
                .padding(.horizontal, 8)
                if let parsedHand = parsedHand {
                    ScrollView {
                        Text(String(describing: parsedHand))
                            .foregroundColor(Color(white: 0.85))
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                    // Change background to clear
                    .background(Color.clear)
                    .cornerRadius(10)
                    .padding(.horizontal, 8)
                }
                Spacer()
                Button(action: { onDismiss(); dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Color(white: 0.85))
                        .shadow(radius: 6)
                }
                .padding(.bottom, 14)
            }
            .padding(.top, 8)
            .padding(.horizontal, 14)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
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
                try await handStore.saveHand(parsed)
                DispatchQueue.main.async {
                    showingSuccess = true
                    onDismiss()
                    dismiss()
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
} 
