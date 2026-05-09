// SwiftUI bridge for UIActivityViewController.
//
// Replaces the `UIApplication.shared.connectedScenes.first` pattern, which
// breaks on iPad multi-window and Stage Manager. Use via:
//
//     @State private var shareItem: ShareItem?
//
//     .shareSheet(item: $shareItem)
//
//     // To share:
//     shareItem = ShareItem(items: [url])

import SwiftUI
import UIKit

public struct ShareItem: Identifiable {
    public let id = UUID()
    public let items: [Any]

    public init(items: [Any]) {
        self.items = items
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in onComplete() }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

public extension View {
    /// Present a UIActivityViewController for the given share item. When the
    /// user taps an action or dismisses the sheet, the binding is cleared.
    func shareSheet(item: Binding<ShareItem?>) -> some View {
        sheet(item: item) { current in
            ActivityView(items: current.items) {
                item.wrappedValue = nil
            }
        }
    }
}
