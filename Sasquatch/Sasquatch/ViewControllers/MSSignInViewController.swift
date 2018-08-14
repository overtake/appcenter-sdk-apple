import UIKit
import WebKit

class MSSignInViewController: UIViewController, WKNavigationDelegate {

  var onAuthDataRecieved: ((_ token: String, _ userId: String, _ expiresAt: Date) -> Void)?

  enum AuthAction {
    case login, refresh, signout
  }

  var webView: WKWebView!

  let baseUrl = "https://login.live.com/oauth20_"
  let redirectEndpoint = "desktop.srf"
  let authorizeEndpoint = "authorize.srf"
  let tokenEndpoint = "token.srf"
  let signOutEndpoint = "logout.srf"
  let clientId = "000000004C1D3F6C"
  let scope = "service::events.data.microsoft.com::MBI_SSL"
  let refreshTokenParam = "refresh_token"
  lazy var clientIdParam = { return "&client_id=" + self.clientId }()
  lazy var redirectParam = { return "redirect_uri=" + (self.baseUrl + self.redirectEndpoint).addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)! }()
  lazy var refreshParam = { return "&grant_type=" + self.refreshTokenParam + "&" + self.refreshTokenParam + "=" + self.refreshToken}()
  lazy var scopeParam = { return "&scope=" + self.scope }()
  
  var refreshToken = ""
  
  var action: AuthAction = .login

  override func loadView() {
    let configuration = WKWebViewConfiguration()
    configuration.preferences.javaScriptEnabled = true
    self.webView = WKWebView(frame: .zero, configuration: configuration)
    self.webView.navigationDelegate = self
    view = self.webView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    process()
  }

  func process() {
    switch self.action {
    case .login:
      self.login()
    case .refresh:
      self.refresh()
    case .signout:
      self.signOut()
    }
  }

  func login() {
    if let signInUrl = URL(string: self.baseUrl + self.authorizeEndpoint + "?" + redirectParam + clientIdParam + "&response_type=token" + scopeParam) {
      self.webView.load(URLRequest(url: signInUrl))
    }
  }

  enum JSONError: String, Error {
    case NoData = "ERROR: no data"
    case ConversionFailed = "ERROR: conversion from JSON failed"
  }
  
  func refresh() {
    if let refreshUrl = URL(string: self.baseUrl + self.tokenEndpoint) {
      let config = URLSessionConfiguration.default
      let session = URLSession(configuration: config)
      let request = NSMutableURLRequest(url: refreshUrl)
      request.httpMethod = "POST"
      request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
      let bodyString = redirectParam + clientIdParam + refreshParam + scopeParam
      let data: Data = bodyString.data(using: String.Encoding.utf8)!
      
      session.uploadTask(with: request as URLRequest, from: data) { (data, response, error) in
        defer {
          self.close()
        }
        do {
          guard let data = data else {
            throw JSONError.NoData
          }
          guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
            throw JSONError.ConversionFailed
          }
          if let error = json["error"] as? String, let errorDescription = json["error_description"] as? String {
            print("ERROR: \"\(error)\": \(errorDescription)")
            return
          }
          let token = json["access_token"]! as! String
          let expiresIn = json["expires_in"]! as! Int64
          let userId = json["user_id"]! as! String
          self.onAuthDataRecieved?(token, userId, Date().addingTimeInterval(Double(expiresIn)))
        } catch let error as JSONError {
          print(error.rawValue)
        } catch let error as NSError {
          print(error.debugDescription)
        }
        }.resume()
    }
  }

  func signOut() {
    if let url = URL(string: self.baseUrl + self.signOutEndpoint + "?" + redirectParam + clientIdParam) {
      self.webView.load(URLRequest(url: url))
    }
  }

  func checkSignIn(url: URL) {
    if url.absoluteString.starts(with: (self.baseUrl + self.redirectEndpoint)) {
      if let newUrl = URL(string: self.baseUrl + self.redirectEndpoint + "?" + url.fragment!) {
        let refreshToken = newUrl.valueOf(self.refreshTokenParam)!
        if(!refreshToken.isEmpty) {
          self.refreshToken = refreshToken
          self.refresh()
        }
      }
    }
  }

  func checkSignOut(url: URL) {
    if url.absoluteString.starts(with: (self.baseUrl + self.redirectEndpoint)) {
      if let error = url.valueOf("error") {
        print("Error while signing out: %@", error)
      } else {
        print("Successfully signed out")
      }
      close()
    }
  }

  func close() {
    self.dismiss(animated: true, completion: nil)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    switch action {
    case .login:
      checkSignIn(url: webView.url!)
    case .signout:
      checkSignOut(url: webView.url!)
    case .refresh:
      refresh()
    }
  }
}

extension URL {
  func valueOf(_ queryParamaterName: String) -> String? {
    guard let url = URLComponents(string: self.absoluteString) else { return nil }
    return url.queryItems?.first(where: { $0.name == queryParamaterName })?.value
  }
}
