import SwiftUI

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
                        Button(action: { /* TODO: Implement Edit Action */ }) {
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

                        Button(action: { /* TODO: Implement Delete Action */ }) {
                            Text("Delete")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
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
