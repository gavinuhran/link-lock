import SwiftUI
import VisionKit

struct QRScannerView: UIViewControllerRepresentable {

    var onURLScanned: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onURLScanned: onURLScanned)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}
}

extension QRScannerView {

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {

        var onURLScanned: (URL) -> Void
        private var didFire = false

        init(onURLScanned: @escaping (URL) -> Void) {
            self.onURLScanned = onURLScanned
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !didFire else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let payload = barcode.payloadStringValue,
                   let url = URL(string: payload),
                   url.isHTTPOrHTTPS {
                    didFire = true
                    onURLScanned(url)
                    return
                }
            }
        }
    }
}
