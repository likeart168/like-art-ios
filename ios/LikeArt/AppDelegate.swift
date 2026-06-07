import UIKit
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        let webView = WKWebView(frame: UIScreen.main.bounds, configuration: config)
        
        if let wwwPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "www") {
            let wwwURL = URL(fileURLWithPath: wwwPath)
            webView.loadFileURL(wwwURL, allowingReadAccessTo: wwwURL.deletingLastPathComponent())
        }
        
        let vc = UIViewController()
        vc.view = webView
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        return true
    }
}
