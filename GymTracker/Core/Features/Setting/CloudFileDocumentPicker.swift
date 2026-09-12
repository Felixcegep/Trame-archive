import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// System Files picker so iCloud Drive and Google Drive (and other providers)
/// share one path. Create exports a temporary backup; Open links an existing
/// JSON in place.
struct CloudFileDocumentPicker: UIViewControllerRepresentable {
    enum Mode {
        case create(URL)
        case open
    }

    let mode: Mode
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        switch mode {
        case .create(let url):
            picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        case .open:
            picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [.json],
                asCopy: false
            )
        }
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else { return }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
