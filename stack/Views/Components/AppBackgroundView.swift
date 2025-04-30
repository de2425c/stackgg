import SwiftUI

struct AppBackgroundView: View {
    private let baseDarkColor = Color(red: 0.05, green: 0.05, blue: 0.09) // Slightly reduced blue component
    private let radialCenterColor = Color(red: 0.18, green: 0.20, blue: 0.25) // Slightly lighter blue/teal/grey

    var body: some View {
        ZStack {
            // Base dark color covering everything
            baseDarkColor
                .ignoresSafeArea()

            // Radial highlight at the top, subtle opacity
            RadialGradient(
                gradient: Gradient(colors: [radialCenterColor.opacity(0.5), baseDarkColor.opacity(0.0)]), // Subtle fade
                center: UnitPoint(x: 0.5, y: 0.15), // Centered horizontally, near the top
                startRadius: 10,
                endRadius: 450 // Adjust size as needed
            )
            .ignoresSafeArea()
        }
    }
}

// Optional Preview
struct AppBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        AppBackgroundView()
    }
} 