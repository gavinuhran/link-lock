import Foundation

extension URL {
    /// Returns true if `self` and `other` refer to the same resource,
    /// ignoring any fragment (#section). This allows same-page anchor
    /// navigation while blocking everything else.
    func sameResource(as other: URL) -> Bool {
        guard var a = URLComponents(url: self, resolvingAgainstBaseURL: false),
              var b = URLComponents(url: other, resolvingAgainstBaseURL: false) else {
            return self == other
        }
        a.fragment = nil
        b.fragment = nil
        return a.url == b.url
    }

    /// The scheme lowercased, or nil if not present.
    var schemeLowercased: String? { scheme?.lowercased() }

    /// Returns true if the scheme is http or https (case-insensitive).
    var isHTTPOrHTTPS: Bool {
        let s = schemeLowercased
        return s == "http" || s == "https"
    }
}
