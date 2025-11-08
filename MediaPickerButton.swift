import SwiftUI
internal import PhotosUI

enum MediaType {
    case photo
    case video
    case both
    
    var pickerFilter: PHPickerFilter {
        switch self {
        case .photo:
            return .images
        case .video:
            return .videos
        case .both:
            return .any(of: [.images, .videos])
        }
    }
}

struct MediaPickerButton: View {
    @Binding var selectedImage: UIImage?
    @Binding var selectedVideoURL: URL?
    
    let mediaType: MediaType
    let title: String
    let subtitle: String
    let showPreview: Bool
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    init(
        selectedImage: Binding<UIImage?> = .constant(nil),
        selectedVideoURL: Binding<URL?> = .constant(nil),
        mediaType: MediaType = .photo,
        title: String = "Add Media",
        subtitle: String = "Tap to select from library",
        showPreview: Bool = true
    ) {
        self._selectedImage = selectedImage
        self._selectedVideoURL = selectedVideoURL
        self.mediaType = mediaType
        self.title = title
        self.subtitle = subtitle
        self.showPreview = showPreview
    }
    
    var body: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: mediaType.pickerFilter) {
            HStack(spacing: 12) {
                if showPreview {
                    previewView
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasMedia ? "Change \(mediaType == .video ? "Video" : "Photo")" : title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.purple.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.purple.opacity(0.4))
                    .font(.caption)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.3)))
            .cornerRadius(12)
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if mediaType == .video || mediaType == .both {
                    // Try loading as video first
                    if let movie = try? await newItem?.loadTransferable(type: Movie.self) {
                        await MainActor.run {
                            selectedVideoURL = movie.url
                        }
                        return
                    }
                }
                
                // Load as image with proper error handling and color space conversion
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    // Create image and ensure it's in a compatible color space
                    if let sourceImage = UIImage(data: data) {
                        // Redraw the image to ensure it's in a compatible format
                        let format = UIGraphicsImageRendererFormat()
                        format.scale = sourceImage.scale
                        format.opaque = false
                        
                        let renderer = UIGraphicsImageRenderer(size: sourceImage.size, format: format)
                        let normalizedImage = renderer.image { context in
                            sourceImage.draw(in: CGRect(origin: .zero, size: sourceImage.size))
                        }
                        
                        await MainActor.run {
                            selectedImage = normalizedImage
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var previewView: some View {
        if let image = selectedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .cornerRadius(8)
                .clipped()
        } else if selectedVideoURL != nil {
            ZStack {
                Color.black.opacity(0.3)
                Image(systemName: "video.fill")
                    .foregroundStyle(.white)
                    .font(.title3)
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
        } else {
            ZStack {
                LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: iconName)
                    .foregroundStyle(.white)
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
        }
    }
    
    private var hasMedia: Bool {
        selectedImage != nil || selectedVideoURL != nil
    }
    
    private var iconName: String {
        switch mediaType {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .both:
            return "photo.on.rectangle"
        }
    }
}

// Helper struct for video loading
struct Movie: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let copy = docs.appendingPathComponent("movie-\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}

// Extension for documents directory
extension URL {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
