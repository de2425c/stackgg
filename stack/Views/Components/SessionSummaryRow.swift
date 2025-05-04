import SwiftUI
import FirebaseFirestore

struct SessionSummaryRow: View {
    let session: Session
    var onTapAction: () -> Void = {}
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateFormatter.string(from: session.startDate))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text(String(format: "%.1f hours", session.hoursPlayed))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(session.profit >= 0 ? "+$\(Int(session.profit))" : "-$\(abs(Int(session.profit)))")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(session.profit >= 0 ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : .red)
            }
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Buy in:")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Text("$\(Int(session.buyIn))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    HStack {
                        Text("Cashout:")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Text("$\(Int(session.cashout))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                    
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(session.gameName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text(session.stakes)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.clear)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapAction)
    }
}

struct SessionDetailsView: View {
    let session: Session
    var onShare: () -> Void = {}
    @Environment(\.dismiss) var dismiss
    @ObservedObject var sessionStore: SessionStore
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false
    @State private var isDeleting = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }
    
    private func formatResult(_ profit: Double) -> String {
        return profit >= 0 ? "+ $\(Int(profit))" : "- $\(abs(Int(profit)))"
    }
    
    var body: some View {
        ZStack {
            Color(red: 30/255, green: 30/255, blue: 30/255).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Session Details")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color(red: 40/255, green: 40/255, blue: 40/255))

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRow(label: "Date", value: dateFormatter.string(from: session.startDate))
                        DetailRow(label: "Time", value: "\(timeFormatter.string(from: session.startDate)) - \(timeFormatter.string(from: session.endTime))")
                        DetailRow(label: "Game", value: session.gameName)
                        DetailRow(label: "Stakes", value: session.stakes)
                        DetailRow(label: "Buy-in", value: "$\(Int(session.buyIn))")
                        DetailRow(label: "Cash out", value: "$\(Int(session.cashout))")
                        DetailRow(label: "Result", value: formatResult(session.profit), valueColor: session.profit >= 0 ? .green : .red)
                    }
                    .padding()
                }

                Spacer()

                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Button(action: { showingEditSheet = true }) {
                            Text("Edit")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.clear)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        }

                        Button(action: { showingDeleteConfirmation = true }) {
                            HStack {
                                Text("Delete")
                                    .fontWeight(.semibold)
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.red)
                            .cornerRadius(10)
                        }
                        .disabled(isDeleting)
                        .opacity(isDeleting ? 0.7 : 1)
                    }

                    Button(action: {
                        dismiss()
                        onShare()
                    }) {
                        Text("Share Session")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                .padding()
            }
        }
        .alert("Delete Session", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteSession() }
        } message: {
            Text("Are you sure you want to delete this session? This action cannot be undone.")
        }
        .sheet(isPresented: $showingEditSheet) {
            SessionEditView(session: session, sessionStore: sessionStore, onDismiss: { 
                dismiss()
            })
        }
    }
    
    private func deleteSession() {
        isDeleting = true
        
        sessionStore.deleteSession(session.id) { error in
            DispatchQueue.main.async {
                isDeleting = false
                
                if error == nil {
                    dismiss()
                } else {
                    // In a real app, you might want to show an error alert here
                    print("Error deleting session: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
}

// Add a new edit view for sessions
struct SessionEditView: View {
    let session: Session
    @ObservedObject var sessionStore: SessionStore
    var onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var gameName: String
    @State private var stakes: String
    @State private var startDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var buyIn: String
    @State private var cashout: String
    @State private var isLoading = false
    
    init(session: Session, sessionStore: SessionStore, onDismiss: @escaping () -> Void) {
        self.session = session
        self.sessionStore = sessionStore
        self.onDismiss = onDismiss
        
        // Initialize state with session values
        _gameName = State(initialValue: session.gameName)
        _stakes = State(initialValue: session.stakes)
        _startDate = State(initialValue: session.startDate)
        _startTime = State(initialValue: session.startTime)
        _endTime = State(initialValue: session.endTime)
        _buyIn = State(initialValue: String(format: "%.2f", session.buyIn))
        _cashout = State(initialValue: String(format: "%.2f", session.cashout))
    }
    
    private var calculatedHoursPlayed: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute], from: startTime, to: endTime)
        let totalMinutes = Double(components.minute ?? 0)
        let hours = totalMinutes / 60.0
        return String(format: "%.1f", hours)
    }
    
    private var profit: Double {
        let buyInValue = Double(buyIn) ?? 0
        let cashoutValue = Double(cashout) ?? 0
        return cashoutValue - buyInValue
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackgroundView()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Game and stakes
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Game Info")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 16) {
                                // Game Name
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Game")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    TextField("Game", text: $gameName)
                                        .foregroundColor(.white)
                                        .font(.system(size: 18))
                                        .padding()
                                        .background(Color.black.opacity(0.3))
                                        .cornerRadius(10)
                                }
                                
                                // Stakes
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Stakes")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    TextField("Stakes", text: $stakes)
                                        .foregroundColor(.white)
                                        .font(.system(size: 18))
                                        .padding()
                                        .background(Color.black.opacity(0.3))
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Date and Time
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Date & Time")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 16) {
                                // Start date
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Start Date")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    DatePicker("", selection: $startDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        .padding()
                                        .background(Color.black.opacity(0.3))
                                        .cornerRadius(10)
                                }
                                
                                // Time range
                                HStack(spacing: 12) {
                                    // Start time
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Start Time")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray)
                                        
                                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .colorScheme(.dark)
                                            .padding()
                                            .background(Color.black.opacity(0.3))
                                            .cornerRadius(10)
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    // End time
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("End Time")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray)
                                        
                                        DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .colorScheme(.dark)
                                            .padding()
                                            .background(Color.black.opacity(0.3))
                                            .cornerRadius(10)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Financial details
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Financial Details")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 16) {
                                // Buy-in field
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Buy In")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    HStack {
                                        Text("$")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 18, weight: .semibold))
                                        
                                        TextField("0.00", text: $buyIn)
                                            .keyboardType(.decimalPad)
                                            .foregroundColor(.white)
                                            .font(.system(size: 20, weight: .medium))
                                            .frame(height: 44)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(10)
                                }
                                
                                // Cashout field
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Cashout")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    HStack {
                                        Text("$")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 18, weight: .semibold))
                                        
                                        TextField("0.00", text: $cashout)
                                            .keyboardType(.decimalPad)
                                            .foregroundColor(.white)
                                            .font(.system(size: 20, weight: .medium))
                                            .frame(height: 44)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(10)
                                }
                                
                                // Profit preview
                                HStack {
                                    Text("Profit:")
                                        .foregroundColor(.gray)
                                    
                                    let isProfit = profit >= 0
                                    Text(String(format: "%@$%.2f", isProfit ? "+" : "", profit))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(isProfit ? 
                                            Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : 
                                            Color.red)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                }
                
                // Save button at bottom
                VStack {
                    Spacer()
                    Button(action: saveChanges) {
                        HStack {
                            Text("Save Changes")
                                .font(.system(size: 17, weight: .bold))
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .padding(.leading, 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                        .foregroundColor(.black)
                        .cornerRadius(27)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func saveChanges() {
        guard let buyInValue = Double(buyIn),
              let cashoutValue = Double(cashout) else { return }
        
        isLoading = true
        
        let hoursPlayed = Double(calculatedHoursPlayed) ?? 0
        
        let updatedSessionData: [String: Any] = [
            "gameName": gameName,
            "stakes": stakes,
            "startDate": Timestamp(date: startDate),
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime),
            "hoursPlayed": hoursPlayed,
            "buyIn": buyInValue,
            "cashout": cashoutValue,
            "profit": cashoutValue - buyInValue,
        ]
        
        let db = Firestore.firestore()
        db.collection("sessions").document(session.id).updateData(updatedSessionData) { error in
            DispatchQueue.main.async {
                isLoading = false
                
                if error == nil {
                    // Refresh sessions after update
                    sessionStore.fetchSessions()
                    dismiss()
                    onDismiss()
                } else {
                    // In a real app, you'd show an error message
                    print("Error updating session: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
        .font(.system(size: 15))
    }
} 
