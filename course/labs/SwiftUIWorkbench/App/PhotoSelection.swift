import SwiftUI
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers
import ImageIO
import Observation

// This sample uses Data transfer for bounded still images, not video/file export.
struct PickedPhoto: Transferable, Sendable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard data.count <= 12 * 1024 * 1024 else { throw PhotoError.tooLarge }
            return PickedPhoto(data: data)
        }
    }
}
enum PhotoError: Error { case tooLarge, unreadable }

@MainActor @Observable
final class PhotoSelection {
    var image: UIImage?
    var status = "No photo selected"
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var task: Task<Void, Never>?
    func select(_ item: PhotosPickerItem?) {
        generation += 1
        let ticket = generation
        task?.cancel()
        image = nil
        guard let item else { status = "Photo selection cleared or canceled"; task = nil; return }
        status = "Loading selected image…"
        task = Task { [weak self] in
            do {
                guard let photo = try await item.loadTransferable(type: PickedPhoto.self) else { throw PhotoError.unreadable }
                try Task.checkCancellation()
                // Decode off the main actor. Send only encoded Data in, a small image out.
                let decoded = await Task.detached(priority: .userInitiated) {
                    guard let source = CGImageSourceCreateWithData(photo.data as CFData, nil) else { return Optional<UIImage>.none }
                    let options: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 1000,
                        kCGImageSourceShouldCacheImmediately: true
                    ]
                    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
                    return UIImage(cgImage: image)
                }.value
                try Task.checkCancellation()
                guard let self, ticket == self.generation else { return }
                guard let decoded else { throw PhotoError.unreadable }
                self.image = decoded
                self.status = "Current selection loaded; thumbnail kept only in memory"
                self.task = nil
            } catch {
                guard let self, ticket == self.generation else { return }
                self.status = error is CancellationError ? "Photo loading canceled" : "Photo load failed or exceeded the 12 MiB import limit"
                self.task = nil
            }
        }
    }
    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        image = nil
        status = "Photo loading canceled; in-memory image cleared"
    }
}
