import UIKit
import Social
import UniformTypeIdentifiers
import MobileCoreServices

/// Share Extension view controller.
///
/// Activated when the user taps "Open in Link Lock" from any share sheet.
/// Extracts the shared URL and hands it to the main app via the
/// `linklock://open?url=<encoded>` custom URL scheme.
///
/// Setup required in Xcode:
/// 1. Add a new target: Share Extension (named LinkLockShareExtension).
/// 2. Set this file as the Principal Class in the extension's Info.plist.
/// 3. Replace the default NSExtensionMainStoryboard key with
///    NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).ShareViewController
/// 4. Set NSExtensionActivationRule (see below).
///
/// NSExtensionActivationRule (paste into extension Info.plist):
/// ```xml
/// <key>NSExtensionActivationRule</key>
/// <string>SUBPREDICATE_COUNT(extensionItems[cd].attachments[cd],
///   {NSExtensionItemAttachmentsKey LIKE "public.url"}, 1) == 1</string>
/// ```
///
/// App Groups (optional, for future shared state):
/// - Add the same App Group to both targets if you want shared UserDefaults.
///
/// URL scheme (required in main app Info.plist):
/// ```xml
/// <key>CFBundleURLTypes</key>
/// <array>
///   <dict>
///     <key>CFBundleURLSchemes</key>
///     <array><string>linklock</string></array>
///     <key>CFBundleURLName</key>
///     <string>com.yourname.LinkLock</string>
///   </dict>
/// </array>
/// ```
final class ShareViewController: UIViewController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        extractURL { [weak self] url in
            guard let self else { return }
            if let url {
                self.openMainApp(with: url)
            } else {
                self.completeWithError()
            }
        }
    }

    // MARK: - URL Extraction

    private func extractURL(completion: @escaping (URL?) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            completion(nil)
            return
        }

        // Look for the first public.url attachment.
        let urlType = UTType.url.identifier
        for provider in attachments where provider.hasItemConformingToTypeIdentifier(urlType) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { item, error in
                DispatchQueue.main.async {
                    if let url = item as? URL, url.scheme == "http" || url.scheme == "https" {
                        completion(url)
                    } else if let string = item as? String,
                              let url = URL(string: string),
                              url.scheme == "http" || url.scheme == "https" {
                        completion(url)
                    } else {
                        completion(nil)
                    }
                }
            }
            return // Only process the first matching attachment.
        }
        completion(nil)
    }

    // MARK: - App Handoff

    private func openMainApp(with url: URL) {
        guard var components = URLComponents(string: "linklock://open") else {
            completeWithError(); return
        }
        components.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString)
        ]
        guard let deepLink = components.url else {
            completeWithError(); return
        }

        // Open the main app. The extension context must complete after opening.
        // Using the responder chain to call openURL since extensions can't call
        // UIApplication.shared.open directly.
        var responder: UIResponder? = self
        while let r = responder {
            if let application = r as? UIApplication {
                application.open(deepLink, options: [:], completionHandler: nil)
                break
            }
            responder = r.next
        }

        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func completeWithError() {
        extensionContext?.cancelRequest(withError: ShareExtensionError.unsupportedURL)
    }
}

// MARK: - Error

private enum ShareExtensionError: LocalizedError {
    case unsupportedURL

    var errorDescription: String? {
        "Link Lock only supports http and https URLs."
    }
}
