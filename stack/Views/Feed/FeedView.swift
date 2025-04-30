import SwiftUI

struct FeedView: View {
    var body: some View {
        ZStack {
            AppBackgroundView()
            VStack {
                Spacer()
                Text("Coming Soon")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
        }
    }
} 