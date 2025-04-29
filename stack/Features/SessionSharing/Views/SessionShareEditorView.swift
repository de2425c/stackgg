import SwiftUI
import PhotosUI

struct SessionShareEditorView: View {
    // Use @StateObject for the ViewModel as this view owns it
    @StateObject var viewModel: SessionShareViewModel
    @Environment(\.dismiss) var dismiss

    // State for the share sheet
    @State private var showingShareSheet = false
    @State private var sharedImage: UIImage? = nil
    
    // State for image scaling
    @State private var imageScale: CGFloat = 1.0
    @GestureState private var pinchMagnification: CGFloat = 1.0 // Tracks current gesture magnification
    
    // State for image panning
    @State private var imageOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero // Tracks current drag gesture
    
    // State for drag gesture on widgets
    // No longer just size, but full state including initial position
    @GestureState private var dragState = DragState.inactive
    @State private var activeWidgetId: UUID? = nil // Track which widget is being dragged

    // State for collapsible widget menu
    @State private var isWidgetMenuExpanded = false

    // App specific colors (using placeholders, replace with actual color definitions)
    let appBackgroundColor = Color(UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0))
    let appAccentColor = Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0))
    let appWidgetBackgroundColor = Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0))
    
    // Enum to manage drag state more cleanly
    enum DragState {
        case inactive
        case dragging(id: UUID, translation: CGSize)
        
        var translation: CGSize {
            switch self {
            case .inactive: return .zero
            case .dragging(_, let translation): return translation
            }
        }
        
        var isDragging: Bool {
            switch self {
            case .inactive: return false
            case .dragging: return true
            }
        }
        
        var id: UUID? {
            switch self {
            case .inactive: return nil
            case .dragging(let id, _): return id
            }
        }
    }

    var body: some View {
        // No NavigationView needed here if pushed by NavigationLink
        ZStack {
            // Make the canvas the base layer and allow it to go edge-to-edge
            editorCanvas
                .ignoresSafeArea()
                
            // Overlay for buttons and menu
            overlayControls
            
            // Loading Indicator (keep on top)
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.4))
                    .ignoresSafeArea()
            }
        }
        // Remove Navigation Title
        // .navigationTitle("Share Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true) // Hide default back button
        .toolbarBackground(.hidden, for: .navigationBar)
        // Remove explicit toolbar background for transparency
        // .toolbarBackground(Material.ultraThin, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                   HStack {
                       Image(systemName: "chevron.left") // Standard back icon
                           .font(.system(size: 18, weight: .semibold))
                       Text("Back")
                   }
                }
                .foregroundColor(appAccentColor)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Share") {
                    shareSession()
                }
                .foregroundColor(appAccentColor)
                .disabled(viewModel.selectedImage == nil) // Disable if no image selected
            }
        }
        .toolbar(.hidden, for: .tabBar) // <<< HIDE TAB BAR
        // Present the Photos Picker
        .photosPicker(
            isPresented: $viewModel.isShowingPhotoPicker, 
            selection: $viewModel.selectedPhotoPickerItem,
            matching: .images // Only allow images
        )
        // Present the Share Sheet
        .sheet(isPresented: $showingShareSheet) {
            if let imageToShare = sharedImage {
                ActivityViewController(activityItems: [imageToShare])
            }
        }
        // Show Error Messages
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
            Button("OK") { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        })
    }

    // MARK: - Editor Canvas View
    private var editorCanvas: some View {
        GeometryReader { geometry in
            // Add tap gesture to close menu when tapping canvas
            let menuCloseTap = TapGesture().onEnded { _ in 
                if isWidgetMenuExpanded {
                    withAnimation {
                        isWidgetMenuExpanded = false
                    }
                }
            }

            ZStack {
                // Background Image or Placeholder (now fills the geometry)
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .offset(x: imageOffset.width + dragOffset.width, y: imageOffset.height + dragOffset.height) // Apply combined offset
                        .scaleEffect(imageScale * pinchMagnification) // Apply combined scale
                        .scaledToFill()
                        // Ensure it fills the geometry provided
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped() // Clip to bounds
                        // Combine Drag and Magnification
                        .gesture(
                            SimultaneousGesture(
                                DragGesture()
                                    .updating($dragOffset) { value, state, transaction in
                                        state = value.translation
                                    }
                                    .onEnded { value in
                                        // Add the final drag translation to the persistent offset
                                        imageOffset.width += value.translation.width
                                        imageOffset.height += value.translation.height
                                    },
                                MagnificationGesture()
                                    .updating($pinchMagnification) { value, state, transaction in
                                        state = value // Update live magnification state
                                    }
                                    .onEnded { value in
                                        imageScale *= value // Apply final magnification to persistent scale
                                    }
                            )
                        )
                } else {
                    // Placeholder when no image is selected
                    ZStack {
                        // Use app background instead of gray
                        appBackgroundColor
                        VStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Tap to Add Photo")
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                        }
                    }
                    .onTapGesture { viewModel.isShowingPhotoPicker = true }
                }

                // Render Widgets
                ForEach($viewModel.widgets) { $widget in
                    let dragGesture = DragGesture()
                        .updating($dragState) { value, state, transaction in
                            // Update the state only for the widget being dragged
                            // Check if we are already dragging something, if not, start dragging this one
                            switch state {
                            case .inactive:
                                // If currently inactive, start dragging this widget
                                state = .dragging(id: widget.id, translation: value.translation)
                                activeWidgetId = widget.id // Track the widget being actively dragged
                            case .dragging(let currentId, _):
                                // If already dragging, only update if it's the same widget
                                if currentId == widget.id {
                                    state = .dragging(id: widget.id, translation: value.translation)
                                }
                                // If dragging a different widget, do nothing to the state for this gesture update
                            }
                        }
                        .onEnded { value in
                             // Only update the position if this widget was the one being dragged
                            if activeWidgetId == widget.id {
                                // Calculate new position based on drag translation
                                let currentPosition = widget.position == .zero ? CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2) : widget.position
                                let newPosition = CGPoint(x: currentPosition.x + value.translation.width,
                                                          y: currentPosition.y + value.translation.height)
                                
                                // Update the position in the actual widget state
                                widget.position = newPosition
                                viewModel.updateWidgetPosition(widget, newPosition: newPosition) // Also update in ViewModel if needed for persistence
                            }
                            activeWidgetId = nil // Reset active widget tracker
                        }
                    
                    WidgetView(widget: $widget, session: viewModel.session)
                        .position(widget.position == .zero ?
                                  CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2) : // Center initial position
                                  widget.position // Use stored position
                                 )
                        // Apply translation only to the actively dragged widget
                        .offset(dragState.id == widget.id ? dragState.translation : .zero)
                        .gesture(dragGesture)
                        .animation(.interactiveSpring(), value: dragState.isDragging) // Smooth drag effect
                }
            }
            // Ensure the ZStack fills the geometry
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle()) // Make ZStack tappable for menu closing
            .simultaneousGesture(menuCloseTap) // Add tap gesture
        }
    }

    // MARK: - Overlay Controls (Menu Button & Panel)
    private var overlayControls: some View {
        ZStack(alignment: .bottomTrailing) {
            // Ensure it takes up space but is invisible
            Color.clear

            // Use ZStack for positioning button and panel in the same spot
            ZStack(alignment: .bottomTrailing) {
                // Widget Menu Panel (shows when expanded)
                if isWidgetMenuExpanded {
                    widgetMenuPanel
                        // Scale out from bottom right corner
                        .transition(.scale(scale: 1, anchor: .bottomTrailing).combined(with: .opacity))
                }

                // Widget Menu Toggle Button
                if viewModel.selectedImage != nil && !isWidgetMenuExpanded {
                    widgetMenuToggleButton
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) + 16)
        }
        .ignoresSafeArea(.keyboard)
    }

    // Button to toggle the widget menu
    private var widgetMenuToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isWidgetMenuExpanded.toggle()
            }
        } label: {
            Image(systemName: "plus.circle.fill") // Changed icon
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(appAccentColor)
                .background(Circle().fill(appBackgroundColor.opacity(0.8))) // Slightly opaque background
                .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
                .rotationEffect(.degrees(isWidgetMenuExpanded ? 45 : 0)) // Rotate plus to X
        }
    }

    // Panel containing widget add buttons
    private var widgetMenuPanel: some View {
        // Outer VStack for background and fixed X button
        VStack(spacing: 0) { 
            ScrollView { // Scrollable area for widget buttons
                VStack(spacing: 12) {
                    // Buttons to add each type of widget
                    ForEach(ShareWidgetType.allCases) { widgetType in
                         Button {
                            viewModel.addWidget(type: widgetType)
                            closeMenu()
                        } label: {
                           ToolbarIcon(
                                systemName: widgetIcon(for: widgetType),
                                label: widgetType.rawValue,
                                color: .clear // ToolbarIcon already uses clear bg + outline
                           )
                        }
                    }
                }
                .padding([.horizontal, .top]) // Padding inside ScrollView
                .padding(.bottom, 8) // Space before divider
            }
            .frame(maxHeight: 350) // Increased height limit

            Divider().background(Color.white.opacity(0.2))
            
            // Fixed Close button area
            HStack {
                Spacer()
                Button {
                    closeMenu()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }
            .padding(.vertical, 10) // Padding around the close button
        }
        .frame(width: 100) // << Add width constraint here
        .background(.ultraThinMaterial) // Use material for panel background
        .cornerRadius(16)
        .shadow(radius: 10)
    }

    // Helper to close menu (with animation)
    private func closeMenu() {
         withAnimation {
             isWidgetMenuExpanded = false
         }
     }

    // MARK: - Helper Functions
    
    private func widgetIcon(for type: ShareWidgetType) -> String {
        switch type {
            case .profitLoss: return "dollarsign.arrow.circlepath"
            case .gameInfo: return "suit.spade.fill"
            case .stakes: return "scalemass.fill"
            case .duration: return "timer"
            case .buyIn: return "arrow.down.to.line.circle"
            case .cashout: return "arrow.up.forward.circle"
            case .date: return "calendar"
            case .timeRange: return "clock.fill"
            case .gameAndStakes: return "suit.club.fill"
            case .financialSummary: return "list.bullet.clipboard.fill"
            case .timeAndDate: return "calendar.badge.clock"
        }
    }
    
    private func shareSession() {
        // Ensure no widget is actively being dragged when sharing
        guard !dragState.isDragging else { return }
        
        // Capture the current canvas size geometry is needed for accurate rendering
        // We'll use a GeometryReader reference accessible here (if editorCanvas is the main one)
        // OR pass the size down somehow. Let's assume we can get canvasSize.
        // *** This part needs refinement based on how canvasSize is accessed ***
        // For now, we'll assume a placeholder or that geometry is available
        // A common pattern is to store the geometry.size in a @State variable 
        // updated via .onPreferenceChange or similar from the GeometryReader
        let canvasSize = UIScreen.main.bounds.size // Placeholder - Needs actual canvas size
        print("⚠️ Using screen bounds as placeholder for canvas size. Actual size needed for accuracy.")

        sharedImage = viewModel.generateSharedImage(
            imageScale: imageScale, // Pass current scale
            imageOffset: imageOffset, // Pass current offset
            canvasSize: canvasSize // Pass actual canvas size
        )

        if sharedImage != nil {
            showingShareSheet = true
        } else {
            // Error message should be set by viewModel
            print("Failed to generate image for sharing.")
        }
    }
}

// MARK: - Toolbar Icon Helper View
struct ToolbarIcon: View {
    let systemName: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) { // Add spacing
            Image(systemName: systemName)
                .font(.system(size: 24)) // Slightly larger icon
            Text(label)
                .font(.caption)
        }
        .frame(width: 60, height: 60)
        // Use clear background and white outline
        .background(.clear)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white, lineWidth: 1.5)
        )
        .foregroundColor(.white)
    }
}


// MARK: - WidgetView (Placeholder - Needs refinement)
struct WidgetView: View {
    @Binding var widget: ShareWidget
    let session: Session // Pass session data for display

    // Access to ViewModel formatters (or move formatters to a shared place)
    private let formatter = SessionDataFormatter() // Use a dedicated formatter struct/class
    
    var body: some View {
        VStack(alignment: widgetContentAlignment(widget.type)) {
            Text(widgetContent())
                .font(.system(size: isCombinedWidget(widget.type) ? 28 : 36, weight: .bold))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(widget.type == .profitLoss ? (session.profit >= 0 ? Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)) : .red) : .white)
                .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
        }
        .scaleEffect(widget.scale)
        .rotationEffect(widget.rotation)
    }
    
    private func widgetContent() -> String {
        switch widget.type {
        case .profitLoss: return formatter.formatProfit(session.profit)
        case .gameInfo: return formatter.formatGameType(session)
        case .stakes: return formatter.formatStakes(session)
        case .duration: return formatter.formatDuration(session.hoursPlayed)
        case .buyIn: return formatter.formatCurrency(session.buyIn)
        case .cashout: return formatter.formatCurrency(session.cashout)
        case .date: return formatter.formatDate(session.startDate)
        case .timeRange: return formatter.formatTimeRange(start: session.startTime, end: session.endTime)
        case .gameAndStakes: return formatter.formatGameAndStakes(session)
        case .financialSummary: return formatter.formatFinancialSummary(session)
        case .timeAndDate: return formatter.formatTimeAndDate(session)
        }
    }
    
    private func isCombinedWidget(_ type: ShareWidgetType) -> Bool {
        switch type {
        case .gameAndStakes, .financialSummary, .timeAndDate: return true
        default: return false
        }
    }
    
    private func widgetContentAlignment(_ type: ShareWidgetType) -> HorizontalAlignment {
        switch type {
        case .financialSummary: return .leading
        default: return .center
        }
    }
}

// MARK: - Dedicated Formatter (Example - Refactor from ViewModel)
struct SessionDataFormatter {
    func formatProfit(_ profit: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currencyAccounting
        formatter.currencySymbol = "$"
        formatter.positivePrefix = formatter.plusSign + " "
        formatter.negativePrefix = formatter.minusSign + " "
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: profit)) ?? "$0"
    }
    
    func formatGameType(_ session: Session) -> String {
        let type = session.gameType.isEmpty ? "Game" : session.gameType.capitalized
        return type
    }
    
    func formatStakes(_ session: Session) -> String {
        return session.stakes.isEmpty ? "-" : session.stakes
    }
    
    func formatGameAndStakes(_ session: Session) -> String {
        let type = formatGameType(session)
        let stakes = formatStakes(session)
        guard stakes != "-" else { return type }
        return "\(type) \(stakes)"
    }
    
    func formatDuration(_ hours: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .positional
        let durationInSeconds = hours * 3600
        if durationInSeconds > 0 && durationInSeconds < 60 {
            return "1m"
        } else if durationInSeconds == 0 {
            return "0m"
        } else {
            return formatter.string(from: TimeInterval(durationInSeconds)) ?? "0m"
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    func formatTimeAndDate(_ session: Session) -> String {
        let dateStr = formatDate(session.startDate)
        let timeStr = formatTimeRange(start: session.startTime, end: session.endTime)
        return "\(dateStr)\n\(timeStr)"
    }
    
    func formatFinancialSummary(_ session: Session) -> String {
        let buyInStr = "Buy-in: \(formatCurrency(session.buyIn))"
        let cashoutStr = "Cashout: \(formatCurrency(session.cashout))"
        let profitStr = "P/L: \(formatProfit(session.profit))"
        return "\(buyInStr)\n\(cashoutStr)\n\(profitStr)"
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}


// MARK: - ActivityViewController (UIKit Integration for Sharing)
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
