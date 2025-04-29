import SwiftUI
import CoreGraphics // Needed for CGPoint

// Define the types of stats that can be displayed in a widget
enum ShareWidgetType: String, CaseIterable, Identifiable {
    // Individual Stats
    case profitLoss = "P/L"
    case gameInfo = "Game Type"
    case stakes = "Stakes"
    case duration = "Duration"
    case buyIn = "Buy-in"
    case cashout = "Cashout"
    case date = "Date"
    case timeRange = "Time"

    // Combination Stats
    case gameAndStakes = "Game/Stakes"
    case financialSummary = "Summary"
    case timeAndDate = "Date & Time"
    
    var id: String { self.rawValue }
}

// Represents a single widget placed on the share image
struct ShareWidget: Identifiable, Equatable {
    let id = UUID()
    var type: ShareWidgetType
    var position: CGPoint = .zero // Relative position (0,0 top-left, 1,1 bottom-right) - We'll adjust this later
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero
    var style: String = "Default" // Placeholder for different visual styles

    // Static function to create a widget with default content based on type
    static func placeholder(for type: ShareWidgetType) -> ShareWidget {
        return ShareWidget(type: type)
    }

    // Add Equatable conformance
    static func == (lhs: ShareWidget, rhs: ShareWidget) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.position == rhs.position &&
        lhs.scale == rhs.scale &&
        lhs.rotation == rhs.rotation &&
        lhs.style == rhs.style
    }
} 