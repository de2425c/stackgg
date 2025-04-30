import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// Add a static property for the gradient
extension LinearGradient {
    static let appBackgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.12, green: 0.13, blue: 0.15), // Darker top color
            Color(red: 0.05, green: 0.06, blue: 0.08)  // Darker bottom color
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
}

class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var userService: UserService
    
    enum AuthState {
        case loading
        case signedOut
        case signedIn
    }
    
    init() {
        self.userService = UserService()
        checkAuthState()
    }
    
    func checkAuthState() {
        if let user = Auth.auth().currentUser {
            print("👤 User is signed in with ID: \(user.uid)")
            Task {
                do {
                    try await userService.fetchUserProfile()
                    DispatchQueue.main.async {
                        print("✅ Profile found, setting state to signedIn")
                        self.authState = .signedIn
                    }
                } catch {
                    print("❌ Error fetching profile: \(error)")
                    // Only sign out if it's a permission error
                    if let error = error as? UserServiceError, error == .permissionDenied {
                        try? Auth.auth().signOut()
                        DispatchQueue.main.async {
                            self.userService.currentUserProfile = nil // Clear the profile
                            self.authState = .signedOut
                        }
                    } else {
                        // For other errors, still consider the user signed in
                        DispatchQueue.main.async {
                            self.authState = .signedIn
                        }
                    }
                }
            }
        } else {
            print("👤 No user signed in")
            self.userService.currentUserProfile = nil // Clear the profile
            self.authState = .signedOut
        }
    }
}

struct MainCoordinator: View {
    @StateObject var authViewModel: AuthViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            switch authViewModel.authState {
            case .loading:
                LoadingView()
            case .signedOut:
                WelcomeView()
            case .signedIn:
                if let userId = Auth.auth().currentUser?.uid {
                    HomePage(userId: userId)
                        .environmentObject(authViewModel.userService)
                } else {
                    Text("Error: No user ID available")
                        .foregroundColor(.red)
                }
            }
        }
        .environmentObject(authViewModel)
        .frame(maxWidth: .infinity, maxHeight: .infinity) 
        // Use the new AppBackgroundView
        .background(AppBackgroundView())
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            // Remove the explicit background color here
            // Color(UIColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0))
            //     .ignoresSafeArea()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
        }
        // Ensure ZStack fills the space if needed, although the parent Group's background should cover it.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
} 