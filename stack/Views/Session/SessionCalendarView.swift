import SwiftUI
import FirebaseFirestore

struct SessionCalendarView: View {
    @ObservedObject var sessionStore: SessionStore
    @State private var displayDate = Date() // Controls the month being viewed
    @State private var sessionToShare: Session? = nil
    @State private var sessionToShowDetails: Session? = nil
    @State private var isCalendarExpanded = true // State to control calendar visibility
    
    // Group sessions by day for the currently displayed month
    private var sessionsByDay: [Date: Double] {
        var dailyProfits: [Date: Double] = [:]
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: displayDate)!
        
        let sessionsInMonth = sessionStore.sessions.filter { $0.startDate >= monthInterval.start && $0.startDate < monthInterval.end }
        
        for session in sessionsInMonth {
            let dayStart = calendar.startOfDay(for: session.startDate)
            dailyProfits[dayStart, default: 0] += session.profit
        }
        return dailyProfits
    }
    
    // Calculate total profit for the displayed month
    private var monthlyProfit: Double {
        sessionsByDay.values.reduce(0, +)
    }
    
    // Generate the days to display in the grid for the current month
    private var daysInMonth: [Date?] {
        let calendar = Calendar.current
        
        // First, ensure we can get the month interval
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayDate) else {
            return []
        }
        
        // Now get the non-optional start date and weekday
        let firstDayOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) // Sunday = 1, Saturday = 7
        
        // We also need the day count, handle potential nil range
        guard let dayCountRange = calendar.range(of: .day, in: .month, for: displayDate) else {
            return []
        }
        let dayCount = dayCountRange.count

        var days: [Date?] = []
        
        // Add leading empty cells (adjusting for week starting on Monday)
        let weekdayOffset = (firstWeekday == 1) ? 6 : firstWeekday - 2 // Mon = 0, Sun = 6
        days.append(contentsOf: Array(repeating: nil, count: weekdayOffset))
        
        // Add days of the month
        for dayOffset in 0..<dayCount {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols.rotate(by: 1) // Start week on Monday
    private let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 7)
    
    var body: some View {
        VStack(spacing: 16) {
            // Header: Month/Year & Profit (Left) | Navigation & Toggle (Right)
            HStack {
                VStack(alignment: .leading) {
                    Text("\(displayDate, formatter: monthYearFormatter)")
                        .font(.title2.bold())
                    Text(formatProfit(monthlyProfit))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(monthlyProfit >= 0 ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : .red)
                }
                
                Spacer()
                
                HStack(spacing: 16) { // Group navigation and toggle buttons
                    Button {
                        withAnimation {
                            isCalendarExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "calendar") // Calendar icon as toggle
                    }

                    Button {
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    
                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
            }
            .padding(.horizontal)
            .foregroundColor(.white)
            
            // Conditionally display calendar elements with animation
            if isCalendarExpanded {
                VStack {
                    // Weekday Headers
                    HStack {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Calendar Grid
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(daysInMonth.indices, id: \.self) { index in
                            let date = daysInMonth[index]
                            let profit = date != nil ? sessionsByDay[Calendar.current.startOfDay(for: date!)] : nil
                            DayCellView(date: date, profit: profit)
                        }
                    }
                }
                .padding(.horizontal) // Add standard horizontal padding to the container
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .scale.combined(with: .opacity))) // Smooth transition
            }
            
            // Session List for the selected month
            List {
                ForEach(sessionsForDisplayedMonth) { session in
                    SessionSummaryRow(session: session,
                                      onTapAction: { self.sessionToShowDetails = session }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .background(Color.clear)
            .sheet(item: $sessionToShowDetails) { session in
                SessionDetailsView(session: session, onShare: {
                    self.sessionToShare = session
                })
                .presentationDetents([.medium])
            }
            .fullScreenCover(item: $sessionToShare) { session in
                NavigationView {
                    SessionShareEditorView(viewModel: SessionShareViewModel(session: session))
                }
            }
        }
        .padding(.top)
        .background(Color.clear) // Ensure transparent background
        .animation(.default, value: isCalendarExpanded) // Animate changes based on expansion state
    }
    
    // Helper to get sessions for the currently displayed month
    private var sessionsForDisplayedMonth: [Session] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayDate) else { return [] }
        
        return sessionStore.sessions.filter {
            $0.startDate >= monthInterval.start && $0.startDate < monthInterval.end
        }.sorted { $0.startDate > $1.startDate } // Sort recent first
    }
    
    private func changeMonth(by amount: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: amount, to: displayDate) {
            displayDate = newDate
        }
    }
    
    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM, yyyy"
        return formatter
    }
    
    private func formatProfit(_ profit: Double) -> String {
        return "$\(Int(profit))"
    }
}

// Helper to rotate weekday symbols if needed
extension Array {
    func rotate(by amount: Int) -> [Element] {
        guard !self.isEmpty else { return [] }
        let effectiveAmount = amount % self.count
        if effectiveAmount == 0 { return self }
        if effectiveAmount > 0 {
            return Array(self[effectiveAmount...] + self[..<effectiveAmount])
        } else {
            let positiveAmount = -effectiveAmount
            return Array(self[(count - positiveAmount)...] + self[..<(count - positiveAmount)])
        }
    }
} 