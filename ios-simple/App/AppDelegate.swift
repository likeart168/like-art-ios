import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Open Safari with like-art.com — same as Android Intent jump
        if let url = URL(string: "https://like-art.com/") {
            UIApplication.shared.open(url, options: [:]) { _ in
                // Safari opened successfully
            }
        }
        return true
    }
}
