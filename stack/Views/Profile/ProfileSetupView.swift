import SwiftUI

struct ProfileSetupView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var userService = UserService()
    @State private var username = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    let isNewUser: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Complete Your Profile")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Tell us a bit about yourself")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 40)
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            // Username field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                                
                                TextField("", text: $username)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            
                            // Display Name field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display Name (optional)")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                                
                                TextField("", text: $displayName)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                        }
                        .padding(.top, 32)
                        
                        Spacer()
                        
                        // Submit Button
                        Button(action: createProfile) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            } else {
                                Text("Complete Setup")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(username.isEmpty ? Color.gray : Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .disabled(username.isEmpty || isLoading)
                        .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 24)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createProfile() {
        guard !username.isEmpty else { return }
        
        isLoading = true
        Task {
            do {
                try await userService.createUserProfile(
                    username: username,
                    displayName: displayName.isEmpty ? nil : displayName
                )
                DispatchQueue.main.async {
                    if isNewUser {
                        authViewModel.authState = .signedIn
                    }
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = (error as? UserServiceError)?.message ?? "An unexpected error occurred"
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
}

// Custom modifier to handle keyboard
struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                    keyboardHeight = keyboardFrame.height
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    keyboardHeight = 0
                }
            }
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAdaptive())
    }
} 