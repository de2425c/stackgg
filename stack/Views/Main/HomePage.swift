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
    }
    
    enum Tab {
        case dashboard
        case feed
        case add
        case groups
        case profile
        case hands
        case sessions
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardView(userId: userId)
                    .tag(Tab.dashboard)
                
                FeedView()
                    .tag(Tab.feed)
                
                Color.clear
                    .tag(Tab.add)
                
                GroupsView()
                    .tag(Tab.groups)
                
                ProfileScreen(userId: userId)
                    .tag(Tab.profile)
                
                HandsTab(handStore: handStore)
                    .tag(Tab.hands)
                
                SessionsTab(userId: userId)
                    .tag(Tab.sessions)
            }

            CustomTabBar(
                selectedTab: $selectedTab,
                userId: userId,
                showingMenu: $showingMenu
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
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
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: HomePage.Tab
    let userId: String
    @Binding var showingMenu: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Background
            Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0))
                .frame(height: 80)
                .overlay(
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.black.opacity(0.2))
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                            .padding(.top, -12)
                        HStack(spacing: 0) {
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
                                    .offset(y: -18)
                            }
                            .frame(width: 80)
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
                        }
                        .padding(.horizontal, 0)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                )
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .padding(.top, 2) // Move icon up a bit
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.top, -2) // Move text up a bit
            }
            .foregroundColor(isSelected ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : .gray)
            .frame(maxWidth: .infinity)
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
                    .frame(width: 56, height: 56)
                    .shadow(color: Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 0.3)), radius: 10)
                PlusIcon()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.black)
                    .rotationEffect(.degrees(showingMenu ? 45 : 0))
            }
        }
        .padding(.trailing, 12)
        .padding(.bottom, 5)
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
            Color(UIColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0))
                .ignoresSafeArea()
            
            Text("Groups Coming Soon")
                .foregroundColor(.white)
        }
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
                Color(UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0)).ignoresSafeArea()
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
                                    .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
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
                            Text(profile.username)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            if let bio = profile.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            HStack(spacing: 16) {
                                if let location = profile.location, !location.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .foregroundColor(Color.green)
                                        Text(location)
                                            .foregroundColor(.white.opacity(0.7))
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                }
                                if let game = profile.favoriteGame, !game.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "suit.club.fill")
                                            .foregroundColor(Color.green)
                                        Text(game)
                                            .foregroundColor(.white.opacity(0.7))
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                }
                            }
                            .padding(.top, 2)
                            .padding(.bottom, 8)
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
                        .background(
                            RoundedRectangle(cornerRadius: 32)
                                .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 0.95)))
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
        }
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
                Section(header: Text("Username")) {
                    TextField("Username", text: $profile.username)
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
                        PhotosPicker(selection: $imagePickerItem, matching: .images, photoLibrary: .shared()) {
                            Text("Select Photo")
                        }
                        .onChange(of: imagePickerItem) { newItem in
                            if let newItem = newItem {
                                Task {
                                    if let data = try? await newItem.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        DispatchQueue.main.async {
                                            selectedImage = uiImage
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Section(header: Text("Location")) {
                    TextField("Location", text: Binding(
                        get: { profile.location ?? "" },
                        set: { profile.location = $0.isEmpty ? nil : $0 }
                    ))
                }
                Section(header: Text("Bio")) {
                    TextEditor(text: Binding(
                        get: { profile.bio ?? "" },
                        set: { profile.bio = $0.isEmpty ? nil : $0 }
                    ))
                        .frame(height: 80)
                }
                Section(header: Text("Favorite Game")) {
                    Picker("Favorite Game", selection: Binding(
                        get: { profile.favoriteGame ?? "NLH" },
                        set: { profile.favoriteGame = $0 }
                    )) {
                        ForEach(gameOptions, id: \.self) { game in
                            Text(game)
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

struct ProfileImageView: View {
    let url: URL
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        isLoading = true
        error = nil
        
        let session = URLSession(configuration: .default)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("Error loading image: \(error)")
                    self.error = error
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    print("Invalid response")
                    return
                }
                
                if let data = data, let uiImage = UIImage(data: data) {
                    self.image = uiImage
                }
            }
        }.resume()
    }
}

struct AddMenuOverlay: View {
    @Binding var showingMenu: Bool
    let userId: String
    @State private var showHandInput = false
    @Binding var showSessionForm: Bool

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showingMenu = false }
                }
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
                        Button(action: { withAnimation { showingMenu = false } }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .shadow(radius: 8)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, geo.size.height * 0.12)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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
            Color(UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0)).ignoresSafeArea()
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
                                .fill(Color(UIColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0)))
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
                        .fill(Color(UIColor(red: 18/255, green: 19/255, blue: 22/255, alpha: 0.98)))
                )
                .padding(.horizontal, 8)
                if let parsedHand = parsedHand {
                    ScrollView {
                        Text(String(describing: parsedHand))
                            .foregroundColor(Color(white: 0.85))
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                    .background(Color.black.opacity(0.18))
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
