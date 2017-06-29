import Foundation
import PlaygroundSupport
import UIKit

//This page allows you to download a user script for use on the "Browser" page.

//To load a script directly from the internet, enter a URL here that points directly to the .js file for the user script you want.  
//Then tap "Run My Code" to load the script into the playground.

//Note: You may have to load your script again if for some reason it is purged from the playground's memory.

let urlString = "https://gist.githubusercontent.com/sheodox/5daa04083fe73f06d691/raw/a32f25d7493567b4ff6bb52147816122a857ffb6/wkoverride.user.js"

func getStringFromURL(_ string:String) -> String? {
    
    guard let url = URL(string: urlString), 
        let data = try? Data(contentsOf: url), 
        let string = String(data: data, encoding: .utf8) else { return nil}
    
    return string
}

let outputLabel = UILabel(frame: .zero)
outputLabel.backgroundColor = UIColor.white
outputLabel.textAlignment = .center

if let scriptString = getStringFromURL(urlString) {
    if let userScript = String(scriptString) {
        PlaygroundKeyValueStore.current["userScript"] = .string(userScript)
    } else {
        PlaygroundKeyValueStore.current["userScript"] = .string("alert('script could not be loaded')")
    }
    outputLabel.text = "script loaded"
    PlaygroundPage.current.liveView = outputLabel
} else {
    outputLabel.text = "nothing downloaded"
    PlaygroundPage.current.liveView = outputLabel
}
