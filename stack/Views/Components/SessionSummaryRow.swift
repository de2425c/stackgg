import SwiftUI
import FirebaseFirestore

struct SessionSummaryRow: View {
    let session: Session
    @State private var showingDetails = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            VStack(alignment: .leading, spacing: 16) {
                // Top row with date, stakes, and profit
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
                    
                    Text(session.stakes)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.clear)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    Spacer()
                    
                    Text(session.profit >= 0 ? "+$\(Int(session.profit))" : "-$\(abs(Int(session.profit)))")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(session.profit >= 0 ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : .red)
            }
            
                // Bottom row with buy-in and cashout
                HStack {
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
                    
                    // View Details button
                    HStack {
                        Image(systemName: "eye")
                            .font(.system(size: 12))
                        Text("Details")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.clear)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            .padding()
            .background(Color.clear)
            .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetails) {
            SessionDetailsView(session: session)
        }
    }
}

struct SessionDetailsView: View {
    let session: Session
    @Environment(\.dismiss) var dismiss
    @ObservedObject var sessionStore: SessionStore
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false
    @State private var isDeleting = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Apply new background view
                AppBackgroundView()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Coming soon
                        Text("Session details coming soon")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.top, 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
             }
        }
    }
} 