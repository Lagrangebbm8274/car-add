import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Uses Apple's native Files picker and asks iOS to copy the selected document
/// into this app before returning its URL. This avoids relying on a temporary
/// iCloud/File Provider security-scoped URL after the picker closes.
struct PlistDocumentPicker: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // public.item is intentionally broad: plist files with unusual or missing
        // extensions remain selectable. The plist parser validates the actual bytes.
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.item],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: PlistDocumentPicker

        init(parent: PlistDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }
    }
}
