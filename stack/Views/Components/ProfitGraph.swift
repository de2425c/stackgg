import SwiftUI
import Charts

struct ProfitGraph: View {
    @ObservedObject var sessionStore: SessionStore
    
    private var cumulativeProfitData: [(Date, Double)] {
        var cumulative: Double = 0
        let sorted = sessionStore.sessions.sorted { $0.startDate < $1.startDate }
        return sorted.map { session in
            cumulative += session.profit
            return (session.startDate, cumulative)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if cumulativeProfitData.isEmpty {
                Text("No sessions recorded")
                    .foregroundColor(.gray)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                // Chart
                Chart {
                    ForEach(cumulativeProfitData, id: \.0) { date, profit in
                        LineMark(
                            x: .value("Date", date),
                            y: .value("Profit", profit)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)),
                                    Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 0.7))
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                    .interpolationMethod(.monotone)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisValueLabel(format: .dateTime.month().day())
                            .foregroundStyle(Color.gray)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisValueLabel(format: .currency(code: "USD"))
                            .foregroundStyle(Color.gray)
                    }
                }
                
                // Session list
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(sessionStore.sessions.sorted(by: { $0.startDate > $1.startDate }), id: \.id) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatDate(session.startDate))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                                Text("$\(Int(session.profit))")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(session.profit >= 0 ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : .red)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(UIColor(red: 18/255, green: 19/255, blue: 22/255, alpha: 1.0)))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
} 