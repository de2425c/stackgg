import SwiftUI
import FirebaseAuth

struct HomePage: View {
    @State private var selectedTab: Tab = .dashboard
    let userId: String
    
    enum Tab {
        case dashboard
        case feed
        case add
        case groups
        case profile
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView(userId: userId)
                    .tag(Tab.dashboard)
                
                FeedView()
                    .tag(Tab.feed)
                
                Color.clear
                    .tag(Tab.add)
                
                GroupsView()
                    .tag(Tab.groups)
                
                ProfileView()
                    .tag(Tab.profile)
            }
            
            CustomTabBar(selectedTab: $selectedTab, userId: userId)
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: HomePage.Tab
    let userId: String
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0))
                .ignoresSafeArea(edges: .bottom)
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .frame(height: 1),
                    alignment: .top
                )
            
            HStack(spacing: 0) {
                // Left side tabs (Dashboard and Feed)
                HStack(spacing: 0) {
                    TabBarButton(
                        icon: "chart.bar.fill",
                        title: "Dashboard",
                        isSelected: selectedTab == .dashboard
                    ) {
                        selectedTab = .dashboard
                    }
                    
                    TabBarButton(
                        icon: "newspaper.fill",
                        title: "Feed",
                        isSelected: selectedTab == .feed
                    ) {
                        selectedTab = .feed
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Spacer for center button
                Color.clear
                    .frame(width: 80)
                
                // Right side tabs (Groups and Profile)
                HStack(spacing: 0) {
                    TabBarButton(
                        icon: "person.3.fill",
                        title: "Groups",
                        isSelected: selectedTab == .groups
                    ) {
                        selectedTab = .groups
                    }
                    
                    TabBarButton(
                        icon: "person.fill",
                        title: "Profile",
                        isSelected: selectedTab == .profile
                    ) {
                        selectedTab = .profile
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 34)
            
            // Center Add Button
            AddButton(userId: userId)
                .offset(y: -15)
        }
        .frame(height: 92)
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
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : .gray)
            .frame(maxWidth: .infinity)
        }
    }
}

struct AddButton: View {
    let userId: String
    @State private var showingMenu = false
    @State private var showingHandInput = false
    
    var body: some View {
        ZStack(alignment: .top) {
            // Pop-up Menu
            if showingMenu {
                MenuPopup(showingHandInput: $showingHandInput)
                    .offset(y: -65)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Add Button
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
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.black)
                        .rotationEffect(.degrees(showingMenu ? 45 : 0))
                }
            }
        }
        .sheet(isPresented: $showingHandInput) {
            HandInputView(userId: userId)
        }
    }
}

struct MenuPopup: View {
    @Binding var showingHandInput: Bool
    
    var body: some View {
        Button(action: {
            showingHandInput = true
        }) {
            HStack {
                Image(systemName: "doc.text")
                Text("Add a hand")
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
        }
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

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0))
                    .ignoresSafeArea()
                
                VStack {
                    Text("Profile")
                        .foregroundColor(.white)
                        .font(.title)
                        .padding(.top, 20)
                    
                    Spacer()
                    
                    Button(action: signOut) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.8))
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func signOut() {
        do {
            try Auth.auth().signOut()
            authViewModel.checkAuthState()
        } catch {
            print("Error signing out: \(error)")
        }
    }
} 
