import SwiftUI
import Charts

struct ProfitGraph: View {
    @ObservedObject var sessionStore: SessionStore
    @State private var selectedSessionIndex: Int?
    @State private var selectedTimeRange: TimeRange = .week
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "1W"
        case month = "1M"
        case sixMonths = "6M"
        case year = "1Y"
        case all = "All"
        
        var id: String { self.rawValue }
        
        func getDateInterval(from currentDate: Date = Date()) -> Date {
            let calendar = Calendar.current
            switch self {
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: currentDate) ?? currentDate
            case .month:
                return calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
            case .sixMonths:
                return calendar.date(byAdding: .month, value: -6, to: currentDate) ?? currentDate
            case .year:
                return calendar.date(byAdding: .year, value: -1, to: currentDate) ?? currentDate
            case .all:
                return Date.distantPast
        }
    }
    
        var dateDivisions: Int {
            switch self {
            case .week: return 7
            case .month: return 4
            case .sixMonths: return 6
            case .year: return 12
            case .all: return 12
            }
        }
    }
    
    // MARK: - Properties
    
    private var sessions: [Session] {
        return sessionStore.sessions.sorted { $0.startDate < $1.startDate }
    }
    
    private var filteredSessions: [Session] {
        let cutoffDate = selectedTimeRange.getDateInterval()
        return sessions.filter { $0.startDate >= cutoffDate }
    }
    
    private var dateSeries: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let startDate = selectedTimeRange.getDateInterval()
        
        switch selectedTimeRange {
        case .week:
            var dates: [Date] = []
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                    if date <= today {
                        dates.append(date)
                    }
                }
            }
            return dates
            
        case .month:
            var dates: [Date] = []
            for i in 0..<4 {
                if let date = calendar.date(byAdding: .weekOfYear, value: i, to: startDate) {
                    if date <= today {
                        dates.append(date)
                    }
                }
            }
            if let lastDate = dates.last, !calendar.isDate(lastDate, inSameDayAs: today) {
                dates.append(today)
            }
            return dates
            
        case .sixMonths:
            var dates: [Date] = []
            for i in 0..<6 {
                if let date = calendar.date(byAdding: .month, value: i, to: startDate) {
                    if date <= today {
                        dates.append(date)
                    }
                }
            }
            if let lastDate = dates.last, !calendar.isDate(lastDate, inSameDayAs: today) {
                dates.append(today)
            }
            return dates
            
        case .year:
            var dates: [Date] = []
            for i in 0..<12 {
                if let date = calendar.date(byAdding: .month, value: i, to: startDate) {
                    if date <= today {
                        dates.append(date)
                    }
                }
            }
            if let lastDate = dates.last, !calendar.isDate(lastDate, inSameDayAs: today) {
                dates.append(today)
            }
            return dates
            
        case .all:
            return filteredSessions.map { $0.startDate }
        }
    }
    
    private var displayDates: [Date] {
        if dateSeries.isEmpty { return [] }
        if selectedTimeRange == .all { return filteredSessions.map { $0.startDate } }
        
        return dateSeries
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        
        switch selectedTimeRange {
        case .week:
            formatter.dateFormat = "MMM d"
        case .month:
            formatter.dateFormat = "MMM d"
        case .sixMonths, .year:
            formatter.dateFormat = "MMM"
        case .all:
            formatter.dateFormat = "MMM yyyy"
        }
        
        return formatter
    }
    
    private var dateProfit: [(date: Date, profit: Double)] {
        var result: [(date: Date, profit: Double)] = []
        var cumulativeProfit: Double = 0
        let sortedSessions = filteredSessions.sorted { $0.startDate < $1.startDate }
        
        if selectedTimeRange == .all {
            for session in sortedSessions {
                cumulativeProfit += session.profit
                result.append((session.startDate, cumulativeProfit))
            }
            return result
        }
        
                        let calendar = Calendar.current
        
        for (index, date) in dateSeries.enumerated() {
            let nextDate = index + 1 < dateSeries.count ? dateSeries[index + 1] : Date()
            
            for session in sortedSessions {
                if session.startDate >= date && 
                   (index == dateSeries.count - 1 || session.startDate < nextDate) {
                    cumulativeProfit += session.profit
                }
            }
            
            result.append((date, cumulativeProfit))
        }
        
        return result
    }
    
    private var profitValues: [Double] {
        return dateProfit.map { $0.profit }
    }
    
    private var totalProfit: Double {
        profitValues.last ?? 0
    }
    
    private var valueRange: ClosedRange<Double> {
        var maxGraph = profitValues.max() ?? 100
        var minGraph = profitValues.min() ?? 0
        
        if maxGraph == minGraph {
            maxGraph += 50
            minGraph -= 10
        }
        
        let padding = max(abs(maxGraph), abs(minGraph)) * 0.1
        let upperBound = maxGraph + padding
        let lowerBound = minGraph - padding
        
        return lowerBound...upperBound
    }
    
    // Statistics
    private var winRate: Double {
        let profitableSessions = filteredSessions.filter { $0.profit > 0 }.count
        return filteredSessions.isEmpty ? 0 : Double(profitableSessions) / Double(filteredSessions.count) * 100
    }
    
    private var averageProfit: Double {
        filteredSessions.isEmpty ? 0 : filteredSessions.reduce(0) { $0 + $1.profit } / Double(filteredSessions.count)
    }
    
    private var totalSessions: Int {
        filteredSessions.count
    }
    
    private var bestSessionProfit: Double {
        filteredSessions.map { $0.profit }.max() ?? 0
    }
    
    // Add this property for all-time profit
    private var allTimeProfit: Double {
        return sessions.reduce(0) { $0 + $1.profit }
    }
    
    // MARK: - View
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bankroll")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("$\(Int(allTimeProfit))")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(alignment: .center, spacing: 4) {
                    // Show profit for selected time period
                    let isPositive = totalProfit >= 0
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .foregroundColor(isPositive ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : .red)
                        .font(.system(size: 12))
                    
                    Text("$\(abs(Int(totalProfit)))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isPositive ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : .red)
                    
                    Text(selectedTimeRange.rawValue == "All" ? "All time" : "Past \(selectedTimeRange.rawValue.lowercased())")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        
                    Spacer() // Push everything to the left
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if !dateProfit.isEmpty {
                // Remove outer padding to allow edges to extend fully
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Grid background - extend lines fully to edges
                        VStack(spacing: 0) {
                            ForEach(0..<5) { i in
                                Rectangle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 1)
                                    .frame(maxWidth: .infinity) // Ensure full width
                                if i < 4 { Spacer() }
                            }
                        }
                        .frame(maxWidth: .infinity) // Ensure full width
                        .padding(.horizontal, -20) // Extend past safe area
                        
                        // Vertical grid lines
                        HStack(spacing: 0) {
                            ForEach(0..<displayDates.count, id: \.self) { i in
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 1)
                                if i < displayDates.count - 1 {
                                    Spacer()
                                }
                            }
                        }
                        
                        // Line chart - use full width
                        ZStack(alignment: .leading) {
                            // Area below line (subtle gradient)
                            Path { path in
                                let barWidth = geometry.size.width / CGFloat(max(1, dateProfit.count - 1))
                                
                                // Move to first point
                                if let firstProfit = profitValues.first {
                                    let x = CGFloat(0)
                                    let y = geometry.size.height * (1 - CGFloat((firstProfit - valueRange.lowerBound) / (valueRange.upperBound - valueRange.lowerBound)))
                                    path.move(to: CGPoint(x: x, y: y))
                                }
                                
                                // Draw lines to subsequent points
                                for i in 1..<profitValues.count {
                                    let x = CGFloat(i) * barWidth
                                    let y = geometry.size.height * (1 - CGFloat((profitValues[i] - valueRange.lowerBound) / (valueRange.upperBound - valueRange.lowerBound)))
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                                
                                // Add lines to bottom corners to complete the shape
                                if let lastProfit = profitValues.last, profitValues.count > 0 {
                                    let lastX = CGFloat(profitValues.count - 1) * barWidth
                                    let lastY = geometry.size.height * (1 - CGFloat((lastProfit - valueRange.lowerBound) / (valueRange.upperBound - valueRange.lowerBound)))
                                    
                                    path.addLine(to: CGPoint(x: lastX, y: geometry.size.height))
                                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                                    path.closeSubpath()
                                }
                            }
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 0.2)),
                                    Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 0.0))
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            
                            // Line chart
                            Path { path in
                                let barWidth = geometry.size.width / CGFloat(max(1, dateProfit.count - 1))
                                
                                if let firstProfit = profitValues.first {
                                    let x = CGFloat(0)
                                    let y = geometry.size.height * (1 - CGFloat((firstProfit - valueRange.lowerBound) / (valueRange.upperBound - valueRange.lowerBound)))
                                    path.move(to: CGPoint(x: x, y: y))
                    }
                                
                                for i in 1..<profitValues.count {
                                    let x = CGFloat(i) * barWidth
                                    let y = geometry.size.height * (1 - CGFloat((profitValues[i] - valueRange.lowerBound) / (valueRange.upperBound - valueRange.lowerBound)))
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            .stroke(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)), lineWidth: 2)
                            
                            // Overlay points
                            ForEach(0..<profitValues.count, id: \.self) { i in
                                let barWidth = geometry.size.width / CGFloat(max(1, profitValues.count - 1))
                                let x = CGFloat(i) * barWidth
                                let y = geometry.size.height * (1 - CGFloat((profitValues[i] - valueRange.lowerBound) / (valueRange.upperBound - valueRange.lowerBound)))
                                
                                Circle()
                                    .fill(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                                    .frame(width: 6, height: 6)
                                    .position(x: x, y: y)
                            }
                        }
                    }
                }
                .frame(height: 250)
                .edgesIgnoringSafeArea([.leading, .trailing]) // Ignore safe area on sides
                .padding(.top, 8)
                .padding(.horizontal, 0)
                
                // X-axis dates (simplified, centered)
                HStack(spacing: 0) {
                    if !displayDates.isEmpty {
                        ForEach(0..<displayDates.count, id: \.self) { i in
                            Text(dateFormatter.string(from: displayDates[i]))
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.7))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.top, -10)
                .padding(.horizontal, 4)
                
                HStack {
                    Spacer()
                    
                    HStack(spacing: 16) {
                        ForEach(TimeRange.allCases) { range in
                            Button(action: {
                                withAnimation {
                                    selectedTimeRange = range
                                }
                            }) {
                                Text(range.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedTimeRange == range ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : .gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        selectedTimeRange == range ?
                                            Color.gray.opacity(0.3) : Color.clear
                                    )
                                    .cornerRadius(4)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 8)
                
                // Stats Grid
                VStack(spacing: 12) {
                    // First row
                    HStack(spacing: 12) {
                        // Win Rate
                        StatBox(title: "Win Rate", content: {
                            // Win Rate Circle - reduce size
                            ZStack {
                                Circle()
                                    .stroke(lineWidth: 3)
                                    .opacity(0.2)
                                    .foregroundColor(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 0.3)))
                                
                                Circle()
                                    .trim(from: 0.0, to: CGFloat(winRate / 100))
                                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .foregroundColor(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                                    .rotationEffect(Angle(degrees: -90))
                                
                                Text(String(format: "%.1f", winRate))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                            }
                            .frame(width: 50, height: 50)
                        })
                        
                        // Average Profit
                        StatBox(title: "Average Profit", content: {
                            VStack(spacing: 2) {
                                Text("$\(Int(averageProfit))")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Per session")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        })
                    }
                    
                    // Second row
                    HStack(spacing: 12) {
                        // Total Sessions
                        StatBox(title: "Total Sessions", content: {
                            VStack(spacing: 2) {
                                Text("\(totalSessions)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Played")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        })
                        
                        // Best Session
                        StatBox(title: "Best Session", content: {
                            VStack(spacing: 2) {
                                Text("$\(Int(bestSessionProfit))")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Profit")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        })
                        }
                    }
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .frame(height: 250)
            } else {
                Text("No data for selected time period")
                    .foregroundColor(.gray)
                    .frame(height: 150)
            }
        }
        .background(Color.clear) // Ensure the VStack background is clear
    }
}

// MARK: - StatBox View
struct StatBox<Content: View>: View {
    let title: String
    let content: () -> Content
    
    var body: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            
            VStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 8)
                
                Spacer()
                
                content()
                
                Spacer()
                    }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
} 

