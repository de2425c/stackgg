import Foundation
import FirebaseAuth

class AuthService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    init() {
        // Listen for authentication state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    func signInWithEmail(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            DispatchQueue.main.async {
                self.user = result.user
                self.isAuthenticated = true
            }
        } catch {
            throw handleFirebaseError(error)
        }
    }
    
    func signUpWithEmail(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            DispatchQueue.main.async {
                self.user = result.user
                self.isAuthenticated = true
            }
        } catch {
            throw handleFirebaseError(error)
        }
    }
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.user = nil
                self.isAuthenticated = false
            }
        } catch {
            throw AuthError.signOutError
        }
    }
    
    private func handleFirebaseError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue,
             AuthErrorCode.userNotFound.rawValue:
            return .invalidCredentials
        case AuthErrorCode.invalidEmail.rawValue:
            return .invalidEmail
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .emailInUse
        case AuthErrorCode.networkError.rawValue:
            return .networkError
        case AuthErrorCode.weakPassword.rawValue:
            return .weakPassword
        default:
            return .unknown
        }
    }
}

enum AuthError: Error {
    case invalidCredentials
    case networkError
    case invalidEmail
    case emailInUse
    case weakPassword
    case signOutError
    case unknown
    
    var message: String {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error occurred"
        case .invalidEmail:
            return "Invalid email format"
        case .emailInUse:
            return "Email is already in use"
        case .weakPassword:
            return "Password must be at least 6 characters long"
        case .signOutError:
            return "Error signing out"
        case .unknown:
            return "An unknown error occurred"
        }
    }
} 