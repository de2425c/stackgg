import SwiftUI

struct PostView: View {
    let post: Post
    let onLike: () -> Void
    let onComment: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(post.username)
                    .font(.headline)
                Spacer()
                Text(post.createdAt.timeAgo())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Content
            Text(post.content)
                .font(.body)
                .multilineTextAlignment(.leading)
            
            // Interaction buttons
            HStack(spacing: 20) {
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(post.isLiked ? .red : .gray)
                        Text("\(post.likes)")
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: onComment) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.gray)
                        Text("\(post.comments)")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// Extension for Date to show relative time
extension Date {
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
} 