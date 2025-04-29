import SwiftUI
import Combine
import PhotosUI // Needed for photo picker items

class SessionShareViewModel: ObservableObject {
    // Input Session Data
    let session: Session
    
    // Published properties for UI updates
    @Published var selectedImage: UIImage? = nil
    @Published var widgets: [ShareWidget] = []
    @Published var isShowingPhotoPicker = false
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Properties for photo picker
    @Published var selectedPhotoPickerItem: PhotosPickerItem? = nil {
        didSet {
            Task { await loadSelectedPhoto() }
        }
    }

    // Combine cancellables
    private var cancellables = Set<AnyCancellable>()

    init(session: Session) {
        self.session = session
        // Initialize with some default widgets or load saved state if needed
        // For now, let's add a couple of defaults - REMOVED
        // widgets.append(ShareWidget.placeholder(for: .profitLoss))
        // widgets.append(ShareWidget.placeholder(for: .gameInfo))
    }

    // MARK: - Photo Handling
    
    @MainActor // Ensure UI updates happen on the main thread
    private func loadSelectedPhoto() async {
        guard let item = selectedPhotoPickerItem else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                    print("📷 Photo loaded successfully")
                } else {
                    print("❌ Failed to create UIImage from data")
                    errorMessage = "Could not load the selected image."
                }
            } else {
                 print("❌ No data received from PhotosPickerItem")
                 errorMessage = "Could not load image data."
            }
        } catch {
            print("❌ Error loading image: \(error.localizedDescription)")
            errorMessage = "An error occurred while loading the image: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Widget Management
    
    func addWidget(type: ShareWidgetType) {
        let newWidget = ShareWidget.placeholder(for: type)
        widgets.append(newWidget)
        print("➕ Added widget: \(type.rawValue)")
    }

    func removeWidget(_ widget: ShareWidget) {
        widgets.removeAll { $0.id == widget.id }
        print("➖ Removed widget: \(widget.type.rawValue)")
    }

    func updateWidgetPosition(_ widget: ShareWidget, newPosition: CGPoint) {
        if let index = widgets.firstIndex(where: { $0.id == widget.id }) {
            widgets[index].position = newPosition
            // print("↔️ Updated position for widget: \(widget.type.rawValue) to \(newPosition)") // Can be noisy
        }
    }
    
    // Add functions for scale, rotation, style updates as needed

    // MARK: - Image Composition & Sharing
    
    @MainActor
    func generateSharedImage(imageScale: CGFloat, imageOffset: CGSize, canvasSize: CGSize) -> UIImage? {
        guard let baseImage = selectedImage else {
            errorMessage = "Please select an image first."
            return nil
        }
        guard canvasSize != .zero else {
            errorMessage = "Cannot generate image with zero size."
            return nil
        }
        
        isLoading = true
        defer { isLoading = false } // Ensure isLoading is set to false when function exits
        
        // 1. Create UIGraphicsImageRenderer
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale // Use screen scale for sharpness
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        // 2. Render the final image
        let composedImage = renderer.image { context in
            // 3. Draw Background Image with Transformations
            // Calculate the rect to draw the image in, respecting scale and offset
            // This replicates the `.scaledToFill` behavior
            let aspectRatio = baseImage.size.width / baseImage.size.height
            let scaledSize: CGSize
            if canvasSize.width / aspectRatio > canvasSize.height {
                scaledSize = CGSize(width: canvasSize.width * imageScale, height: canvasSize.width / aspectRatio * imageScale)
            } else {
                scaledSize = CGSize(width: canvasSize.height * aspectRatio * imageScale, height: canvasSize.height * imageScale)
            }
            
            // Center the potentially larger scaled image and apply offset
            let originX = (canvasSize.width - scaledSize.width) / 2 + imageOffset.width
            let originY = (canvasSize.height - scaledSize.height) / 2 + imageOffset.height
            let drawRect = CGRect(origin: CGPoint(x: originX, y: originY), size: scaledSize)
            
            baseImage.draw(in: drawRect)

            // 4. Render Widgets
            for widget in widgets {
                // Create the SwiftUI view for the widget
                let widgetView = WidgetView(widget: .constant(widget), session: session)
                                .colorScheme(.dark) // Ensure correct appearance for rendering

                // Use ImageRenderer to capture the SwiftUI view
                let widgetRenderer = ImageRenderer(content: widgetView)
                widgetRenderer.scale = format.scale // Match the main renderer scale
                
                // Get the rendered UIImage for the widget
                guard let widgetUIImage = widgetRenderer.uiImage else { 
                    print("❌ Failed to render widget \(widget.type) to UIImage.")
                    continue // Skip if rendering fails
                }
                let widgetSize = widgetUIImage.size
                
                // Calculate the origin for drawing (position is the center)
                let widgetOriginX = widget.position.x - (widgetSize.width / 2)
                let widgetOriginY = widget.position.y - (widgetSize.height / 2)
                let widgetRect = CGRect(origin: CGPoint(x: widgetOriginX, y: widgetOriginY),
                                        size: widgetSize)
                
                // Draw the rendered widget image directly onto the context
                widgetUIImage.draw(in: widgetRect)
            }
        }
        
        print("🖼️ Shared image generated successfully.")
        return composedImage
    }
    
    // MARK: - Helper Formatters (Move to a dedicated Formatter service later)
    
    func formatProfit(_ profit: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.positivePrefix = formatter.plusSign
        formatter.negativePrefix = formatter.minusSign
        return formatter.string(from: NSNumber(value: profit)) ?? "$0.00"
    }
    
    func formatGameInfo() -> String {
        return "\(session.gameType) \(session.stakes)"
    }
    
    func formatDuration(_ hours: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated // e.g., "1h 30m"
        // Convert hours to seconds for the formatter
        let durationInSeconds = hours * 3600
        return formatter.string(from: TimeInterval(durationInSeconds)) ?? "0h 0m"
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium // e.g., "Sep 12, 2024"
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
} 