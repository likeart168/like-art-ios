import Foundation
import WebKit

/// Read only verified, public pack entries. No network or arbitrary filesystem API.
@MainActor
final class PackMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    private var inFlight = 0
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        let origin = message.frameInfo.securityOrigin
        guard origin.protocol == "https", ["like-art.com", "www.like-art.com"].contains(origin.host),
              [0, 443].contains(origin.port),
              let body = message.body as? [String: Any], let path = body["path"] as? String,
              let number = body["offset"] as? NSNumber, number.doubleValue == Double(number.intValue),
              number.intValue >= 0, inFlight < 4 else {
            replyHandler(nil, "Invalid public pack request"); return
        }
        inFlight += 1
        let offset = number.intValue
        DispatchQueue.global(qos: .userInitiated).async {
            let chunk = WorldPack.shared.chunk(for: path, offset: offset)
            let encoded = chunk?.data.base64EncodedString()
            DispatchQueue.main.async {
                self.inFlight -= 1
                guard let chunk, let encoded else { replyHandler(nil, "Verified pack entry unavailable"); return }
                replyHandler(["base64": encoded, "total": chunk.total, "offset": offset,
                              "mime": WorldPack.mime(path)], nil)
            }
        }
    }
}
