import SwiftUI

struct AppHeaderView: View {
    @EnvironmentObject var userService: UserService
    var title: String // Keep for reference, but don't display it
    var showLeadingButton: Bool
    var onProfileTap: () -> Void
    var trailingView: AnyView?
    var showStackTitle: Bool // New property to show STACK title for profile page
    
    init(
        title: String,
        showLeadingButton: Bool = true,
        onProfileTap: @escaping () -> Void = {},
        trailingView: AnyView? = nil,
        showStackTitle: Bool = false // Default is false
    ) {
        self.title = title
        self.showLeadingButton = showLeadingButton
        self.onProfileTap = onProfileTap
        self.trailingView = trailingView
        self.showStackTitle = showStackTitle
    }
    
    var body: some View {
        HStack(alignment: .center) {
            // Leading content - either profile button or STACK title
            if showStackTitle {
                // STACK title for profile page (left aligned)
                Text("STACK")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(alignment: .leading)
            } else if showLeadingButton {
                // Standard profile button for other pages
                Button(action: onProfileTap) {
                    if let profile = userService.currentUserProfile, 
                       let urlString = profile.avatarURL, 
                       let url = URL(string: urlString) {
                        ProfileImageView(url: url)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 18))
                            )
                    }
                }
            }
            
            Spacer()
            
            // Trailing View (Bell or Custom)
            if let trailingView = trailingView {
                trailingView
            } else {
                // Default: Notification Bell
                Button(action: {}) {
                    Image(systemName: "bell")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(height: 60)
        .background(Color.clear)
    }
}

// Extension for convenience factory methods
extension AppHeaderView {
    // Standard header with notification bell
    static func standard(title: String, showLeadingButton: Bool = true) -> AppHeaderView {
        return AppHeaderView(title: title, showLeadingButton: showLeadingButton, showStackTitle: false)
    }
    
    // Header with logout button
    static func withLogout(title: String, showLeadingButton: Bool = true, onLogout: @escaping () -> Void) -> AppHeaderView {
        let logoutButton = AnyView(
            Button(action: onLogout) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
        )
        return AppHeaderView(
            title: title, 
            showLeadingButton: showLeadingButton, 
            trailingView: logoutButton,
            showStackTitle: false
        )
    }
    
    // Profile header with STACK title and logout button
    static func profileWithStack(onLogout: @escaping () -> Void) -> AppHeaderView {
        let logoutButton = AnyView(
            Button(action: onLogout) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
        )
        return AppHeaderView(
            title: "Profile", 
            showLeadingButton: false, 
            trailingView: logoutButton,
            showStackTitle: true
        )
    }
}
