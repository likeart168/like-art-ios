import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    var activityIndicator: UIActivityIndicatorView!
    var retryButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupActivityIndicator()
        loadWebsite()
    }

    func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        // Allow mixed content and file access for full website functionality
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        webView.configuration.defaultWebpagePreferences = prefs

        view.addSubview(webView)
    }

    func setupActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .gray
        view.addSubview(activityIndicator)
    }

    func loadWebsite() {
        activityIndicator.startAnimating()
        if let url = URL(string: "https://like-art.com/") {
            let request = URLRequest(url: url, timeoutInterval: 30)
            webView.load(request)
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        showRetryButton()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        showRetryButton()
    }

    // MARK: - Retry

    func showRetryButton() {
        if retryButton == nil {
            retryButton = UIButton(type: .system)
            retryButton.setTitle("Tap to Retry", for: .normal)
            retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            retryButton.addTarget(self, action: #selector(retryLoading), for: .touchUpInside)
            retryButton.sizeToFit()
            retryButton.center = view.center
            view.addSubview(retryButton)
        }
        retryButton.isHidden = false
    }

    @objc func retryLoading() {
        retryButton.isHidden = true
        loadWebsite()
    }

    // Allow external links to open in Safari
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        // Keep like-art.com in-app, open external links in Safari
        if url.host?.contains("like-art.com") == true || navigationAction.navigationType == .other {
            decisionHandler(.allow)
        } else if navigationAction.navigationType == .linkActivated {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
}
