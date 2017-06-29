import UIKit 
import PlaygroundSupport
import WebKit

/* Scriptable Browser
 * author: Matt Hayes (github.com/cruinh)
 * license: GPL version 3 or any later version. http://www.gnu.org/copyleft/gpl.html
 * language : Swift 4
 * requirements:  Swift Playgrounds 2 
 *
 * =-=-=-= What is this? =-=-=-=
 * This playground page is a custom browser that can load userscripts into a webpage.  
 *
 * The playground was originally built specifically to allow the "WaniKaniOverride" script to run on review pages at wanikani.com, but it should support loading any script into any page.  Using this brower with other pages/sites may require some modification to the code below, and some scripts may not function as expected.
 * 
 * =-=-=-= Using WaniKaniOverride =-=-=-=
 * To use the browser as-is, navigate through the Swift Playground to the "Download Script" or "Load Custom Script" pages of the Playground Book.  Run one of those scripts to load the user-script.  Then return to this page, and run it to open the browser.  You will be asked to sign in to WaniKani, and then taken to your user dashboard.  From there, go to your reviews and start reviewing kanji/radicals/vocab.  When you first load the page for a review item, the userscript will be injected into the page and an "Ignore Answer" button will appear at the bottom.
 *
 * =-=-=-= Customizing For Different User Scripts =-=-=-=-=
 * To customize this browser for other scripts, first modify the "Download Script" or "Load Custom Script" pages to load the script you want.  Note that loading a custom script may require you to massage the javascript a bit in order for it to work (see comments on that playground page).
 *
 * Once you have your script loaded, come back to this playground page, and create a ScriptAdapter.  You can see the WaniKaniOverrideAdapter below for reference.  The adapter allows you to customize when the script will run.  It allows you to specify extra CSS that will be loaded into the targetted page, in case you need to style elements created by your script..  The adapter also allows you to write a bit of code to alter the javascript as it's loaded into the browser, if necessary.  For example, you may need to strip out code specific to greasemonkey or other script loaders, if your original script was written to work with those.
 *
 * When you have your adapter written, scroll to the bottom of this page, and alter the code to ensure that the browser view controller is being created with your script adapter, rather than a WanikanOverrideAdapter.
 */

let startingURL : URL = URL(string: "http://www.wanikani.com/dashboard")!
var originalScript : String = ""

//Use this key value store to store a script in another Playground page, and then load it into this page.
if let keyValue = PlaygroundKeyValueStore.current["userScript"],
    case .string(let script) = keyValue {
    originalScript = script
}

protocol ScriptAdapter {
    var scriptString : String? { get }
    var scriptExecutionFilters : [String] { get }
    var additionalCSS : String { get }
}

final class WanikanOverrideAdapter : ScriptAdapter {
    init(script : String) {
        scriptString = scriptAdapter.convert(inputScript: script)
    }
    var scriptString : String?
    var scriptExecutionFilters : [String] = ["wanikani.com/review/session"]
    var additionalCSS : String {
        let buttonStyleCSS = "#WKO_button {background-color: #CC0000; color: #FFFFFF; cursor: pointer; display: inline-block; font-size: 0.8125em; padding: 10px; vertical-align: bottom;}"
        let answerFormStyleCSS = "#answer-form fieldset.WKO_ignored input[type=\"text\"]:-moz-placeholder, #answer-form fieldset.WKO_ignored input[type=\"text\"]:-moz-placeholder {color: #FFFFFF; font-family: \"Source Sans Pro\",sans-serif; font-weight: 300; text-shadow: none; transition: color 0.15s linear 0s; } #answer-form fieldset.WKO_ignored button, #answer-form fieldset.WKO_ignored input[type=\"text\"], #answer-form fieldset.WKO_ignored input[type=\"text\"]:disabled { background-color: #FFCC00 !important; }"
        
        return  buttonStyleCSS + answerFormStyleCSS
    }
    func convert(inputScript: String) -> String {
        var moddedUserScript = inputScript.replacingOccurrences(of: "$ = unsafeWindow.$;", with: "//$ = unsafeWindow.$;")
        moddedUserScript = moddedUserScript.replacingOccurrences(of: "GM_addStyle", with: "//GM_addStyle")
        return moddedUserScript
    }
}

class BrowserViewController : UIViewController, WKNavigationDelegate, WKUIDelegate, UITextFieldDelegate {
    var webView : WKWebView!
    var addressLabel : UITextField?
    var forwardButton : UIButton?
    var backButton : UIButton?
    var scriptButton : UIButton?
    var scriptString : String?
    var scriptAlreadyAdded : Bool = false
    var scriptAdapter : ScriptAdapter
    var startingURL : URL
    
    init(startingURL: URL, scriptAdapter: ScriptAdapter) {
        self.startingURL = startingURL
        self.scriptAdapter = scriptAdapter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        webView = _setupWebView()
        view = webView
    }
    
    private var activityIndicator : UIActivityIndicatorView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        edgesForExtendedLayout = []
        
        _setupActivityIndicator()
        _setupAddressView()
        _setupNavigationButtons()
        
        scriptString = scriptAdapter.scriptString
        if scriptString?.count == 0 {
            _showAlert(title: "Warning", message: "You haven't loaded a userScript. To do so, use the \"Download Script\" or \"Load Custom Script\" pages in this Playground Book. Or dismiss this alert and browse normally, if you like.")
        }
        
        loadURL(url: self.startingURL)
    }
    
    func loadURL(string: String?) {
        if let address = string {
            loadURL(url: URL(string: address))
        }
    }
    
    func loadURL(url: URL?) {
        if let url = url {
            let urlRequest = URLRequest(url: url)
            webView.load(urlRequest)
        } else {
            let errorMessage = "Could not load page for URL: \"\(String(describing:url?.absoluteString))\""
            _showError(error: nil,description: errorMessage)
        }
    }
    
    @objc func buttonTapped() {
        _runUserScriptForReviews(webView)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextFieldDidEndEditingReason) {
        switch reason {
            case .committed:
                loadURL(string: textField.text)
            case .cancelled:
                () //do nothing
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        loadURL(string: textField.text)
        textField.resignFirstResponder()
        return false
    }
    
    @objc func forwardButtonTapped() {
        webView.goForward()
    }
    
    @objc func backButtonTapped() {
        webView.goBack()
    }
    
    private func _setupNavigationButtons() {
        forwardButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        forwardButton!.setTitle(">", for: .normal)
        forwardButton!.addTarget(self, action: #selector(forwardButtonTapped), for: .touchUpInside)
        
        backButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        backButton!.setTitle("<", for: .normal)
        backButton!.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        let forwardBarItem = UIBarButtonItem(customView: forwardButton!)
        let backBarItem = UIBarButtonItem(customView: backButton!)
        
        navigationItem.rightBarButtonItems = [forwardBarItem, backBarItem]
    }
    
    private func _setupAddressView() {
        addressLabel = UITextField(frame: CGRect(x: 0, y: 0, width: 325, height: 35))
        addressLabel?.textAlignment = .center
        addressLabel?.textColor = UIColor.darkGray
        addressLabel?.backgroundColor = UIColor.lightGray
        addressLabel?.layer.cornerRadius = 3.0
        addressLabel?.layer.borderColor = UIColor.darkGray.cgColor
        addressLabel?.layer.borderWidth = 0.5
        addressLabel?.delegate = self
        addressLabel?.translatesAutoresizingMaskIntoConstraints = false
        
        addressLabel?.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 0))
        addressLabel?.leftViewMode = .always
        addressLabel?.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 0))
        addressLabel?.rightViewMode = .always
        
        let viewsDict = ["addressLabel":addressLabel]
        var constraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[addressLabel(>=35)]", options: [], metrics: nil, views: viewsDict)
        constraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "H:[addressLabel(>=325)]", options: [], metrics: nil, views: viewsDict))
        addressLabel?.addConstraints(constraints)
        
        navigationItem.titleView = addressLabel
    }
    
    private func _insertCSSString() {
        let cssString = scriptAdapter.additionalCSS
        
        let jsString = "var style = document.createElement('style'); style.innerHTML = '\(cssString)'; document.head.appendChild(style);"
        webView.evaluateJavaScript(jsString, completionHandler: nil)
    }
    
    private func _setupActivityIndicator() {
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        activityIndicator.hidesWhenStopped = true
        self.activityIndicator = activityIndicator
        let navItem = UIBarButtonItem(customView: activityIndicator)
        navigationItem.leftBarButtonItem = navItem
    }
    
    private func _setupWebView() -> WKWebView {
        
        let webViewConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        return webView
    }
    
    //run the user script if any one of the scriptExecutionFilters is a substring of the current URL
    private func _runUserScriptForReviews(_ webView: WKWebView) {
        guard let url = webView.url else { return }
        
        let urlString = url.absoluteString
        
        if scriptAdapter.scriptExecutionFilters.count == 0 {
            _runUserScript()
        }
        else {
            for filter in scriptAdapter.scriptExecutionFilters {
                if urlString.contains(filter) {
                    _runUserScript()
                    break
                } else {
                    debugPrint("filter \(filter) does not match url \(urlString)")
                }
            }
        }
    }
    
    private func _runUserScript() {
        guard scriptAlreadyAdded == false else { 
            print("script already run")
            return 
        }
        guard let webView = webView else { 
            _showError(description:"No webview available to run the userscript in")
            return
        }
        
        if let scriptString = scriptString {
            webView.evaluateJavaScript(scriptString) { [weak self] (something,error) in
                
                if let error = error {
                    self?._showError(error:error)
                    debugPrint("\(String(describing: error))")
                } else {
                    self?.scriptAlreadyAdded = true
                    self?.navigationItem.rightBarButtonItem?.isEnabled = false
                }
                
            }
        } else {
            debugPrint("\(scriptString)")
            _showAlert(message:"There is no user script loaded!  If you meant to use one, run the \"Download Script\", or \"Load Custom Script\" pages and then come back and run this page.")
        }
    }
    
    private func _showAlert(title: String? = nil, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func _showError(error: Error? = nil, description: String? = nil) {
        var errorMessage : String = "Unknown Error"
        if let error = error {
            errorMessage = String(describing:error)
        } else if let description = description {
            errorMessage = description
        }
        let textVC = ErrorViewController.createInNavController(withText:errorMessage, andTitle:"Error")
        present(textVC, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        scriptAlreadyAdded = false
        activityIndicator?.stopAnimating()
        _runUserScriptForReviews(webView)
        _insertCSSString()
        
        let address =  webView.url?.absoluteString
        addressLabel?.text = address
        
        _setNavigationButtonMode(forwardButton, enable: webView.canGoForward)
        _setNavigationButtonMode(backButton, enable: webView.canGoBack)
        
    }
    
    private func _setNavigationButtonMode(_ button: UIButton?, enable: Bool) {
        button?.isEnabled = enable
        if enable {
            button?.setTitleColor(UIColor.darkGray, for: .normal)
            button?.titleLabel?.shadowOffset = CGSize(width: 1, height: 1)
            button?.setTitleShadowColor(UIColor.lightGray, for: .normal)
        } else {
            button?.setTitleColor(UIColor.lightGray, for: .normal)
            button?.titleLabel?.shadowOffset = CGSize(width: 0, height: 0)
            button?.setTitleShadowColor(UIColor.clear, for: .normal)
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator?.startAnimating()
    }
    
    func webView(_ webView: WKWebView, 
                          runJavaScriptAlertPanelWithMessage message: String, 
                          initiatedByFrame frame: WKFrameInfo, 
                          completionHandler: @escaping () -> Void) {
        _showAlert(title: "Alert", message: message)
        completionHandler()
    }
}

class ErrorViewController : UIViewController {
    var text : String?
    var textView : UITextView!
    
    static func createInNavController(withText text: String? = nil, andTitle title:String) -> UINavigationController {
        let viewController = ErrorViewController()
        viewController.text = text
        viewController.navigationItem.title = title
        
        let navController = UINavigationController(rootViewController: viewController)
        return navController
    }
    
    override func loadView() {
        let textView = UITextView(frame: .zero)
        self.textView = textView
        view = textView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let text = self.text {
            textView.text = text
        } else {
            textView.text = ""
        }
        _setupNavBar()
    }
    
    private func _setupNavBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTapped))
    }
    
    @objc func cancelButtonTapped() {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
}

let scriptAdapter = WanikanOverrideAdapter(script: originalScript)
let vc = BrowserViewController(startingURL: startingURL, scriptAdapter: scriptAdapter)
let nav = UINavigationController(rootViewController: vc)
PlaygroundPage.current.liveView = nav
