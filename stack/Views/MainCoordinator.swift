import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .loading
    private let userService = UserService()
    
    enum AuthState {
        case loading
        case signedOut
        case signedIn
    }
    
    init() {
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
            self.authState = .signedOut
        }
    }
}

struct MainCoordinator: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
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
                } else {
                    Text("Error: No user ID available")
                        .foregroundColor(.red)
                }
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(UIColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0))
                .ignoresSafeArea()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
        }
    }
} 