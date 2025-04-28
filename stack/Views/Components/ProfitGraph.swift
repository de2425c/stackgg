import SwiftUI
import Charts

enum TimeRange: String, CaseIterable {
    case hour = "1H"
    case day = "24H"
    case week = "1W"
    case month = "1M"
    case sixMonths = "6M"
    case year = "1Y"
    case all = "All"
}

struct ProfitGraph: View {
    @ObservedObject var sessionStore: SessionStore
    @State private var selectedTimeRange: TimeRange = .week
    @State private var profitData: [(Date, Double)] = []
    
    private var cumulativeProfitData: [(Date, Double)] {
        var cumulative: Double = 0
        return profitData.map { date, profit in
            cumulative += profit
            return (date, cumulative)
        }
    }
    
    private func filterSessions() {
        let now = Date()
        let filteredSessions = sessionStore.sessions.filter { session in
            switch selectedTimeRange {
            case .hour:
                return now.timeIntervalSince(session.startDate) <= 3600
            case .day:
                return now.timeIntervalSince(session.startDate) <= 86400
            case .week:
                return now.timeIntervalSince(session.startDate) <= 604800
            case .month:
                return now.timeIntervalSince(session.startDate) <= 2592000
            case .sixMonths:
                return now.timeIntervalSince(session.startDate) <= 15552000
            case .year:
                return now.timeIntervalSince(session.startDate) <= 31536000
            case .all:
                return true
            }
        }
        
        profitData = filteredSessions.map { ($0.startDate, $0.profit) }
    }
    
    private var isPositiveTrend: Bool {
        guard let lastValue = cumulativeProfitData.last?.1 else { return true }
        return lastValue >= 0
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Time range selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button(action: {
                            selectedTimeRange = range
                            filterSessions()
                        }) {
                            Text(range.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(selectedTimeRange == range ? .white : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedTimeRange == range ?
                                        Color(UIColor.systemGray6) :
                                        Color.clear
                                )
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Chart
            Chart {
                ForEach(cumulativeProfitData, id: \.0) { date, profit in
                    LineMark(
                        x: .value("Date", date),
                        y: .value("Profit", profit)
                    )
                    .foregroundStyle(isPositiveTrend ? Color.green : Color.red)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .currency(code: "USD"))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemGray6))
        )
        .onAppear {
            filterSessions()
        }
        .onChange(of: sessionStore.sessions) { _ in
            filterSessions()
        }
    }
} 