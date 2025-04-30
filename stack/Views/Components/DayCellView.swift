import SwiftUI

struct DayCellView: View {
    let date: Date?
    let profit: Double?
    
    private var dayNumber: String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var isToday: Bool {
        guard let date = date else { return false }
        return Calendar.current.isDateInToday(date)
    }
    
    private var backgroundColor: Color {
        guard let profit = profit else {
            // Make days with no sessions completely clear
            return Color.clear
        }
        return profit >= 0 ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 0.2)) : Color.red.opacity(0.2)
    }
    
    private var foregroundProfitColor: Color {
        guard let profit = profit else { return .clear }
        return profit >= 0 ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : .red
    }
    
    private var foregroundDayColor: Color {
        guard date != nil else { return .clear }
        if isToday {
            // Highlight today with profit color if available, else white
            return profit != nil ? foregroundProfitColor : .white
        }
        // Default to white for other days
        return .white
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(dayNumber)
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(foregroundDayColor)
            
            if let profit = profit {
                Text("$\(Int(profit))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(foregroundProfitColor)
            } else {
                // Keep the space consistent even if there's no profit
                Text(" ") 
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.clear)
            }
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isToday ? foregroundDayColor : Color.clear, lineWidth: 1.5) // Highlight today with appropriate color
                )
        )
    }
}

// Optional Preview
struct DayCellView_Previews: PreviewProvider {
    static var previews: some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 7)) {
            DayCellView(date: nil, profit: nil)
            DayCellView(date: Date(), profit: 200)
            DayCellView(date: Calendar.current.date(byAdding: .day, value: 1, to: Date()), profit: -50)
            DayCellView(date: Calendar.current.date(byAdding: .day, value: 2, to: Date()), profit: 0)
        }
        .padding()
        .background(Color.black)
    }
} 