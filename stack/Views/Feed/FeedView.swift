import SwiftUI

struct FeedView: View {
    var body: some View {
        ZStack {
            Color(UIColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0))
                .ignoresSafeArea()
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