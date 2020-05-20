//
//  LookupTranslationViewController.swift
//  LocalizationEditor
//
//  Created by Mark Fleming, markf@imagemontage.com
//  Copyright © 2020 Mark Fleming. All rights reserved.
//

import Cocoa

protocol LookupTranslationViewControllerDelegate: AnyObject {
    func userDidCancel()
    func userDidAddTranslation(key: String, message: String?)
}

final class LookupTranslationViewController: NSViewController {

    // MARK: - Outlets
    @IBOutlet private weak var window: NSWindow!
    @IBOutlet private weak var fromLanguage: NSPopUpButton!
    @IBOutlet private weak var toLanguage: NSPopUpButton!

    @IBOutlet private weak var msAzureKeyText: NSTextField!

    @IBOutlet private weak var textToSubmitTxtView: NSTextView!
    @IBOutlet private weak var textReturnedTxtView: NSTextView!

    @IBOutlet private weak var exampleBtn: NSButton!
    @IBOutlet private weak var lookupBtn: NSButton!

    // MARK: - Properties
    weak var delegateView: ViewControllerDelegate?

    var listExistingLang: [String] = ["en"]          // list of languages in current .string file group
    var currentRow: Int = 0                     // current row select
    var dataSource: LocalizationsDataSource?

    var arrayLangInfo = [AllLangDetails]() //array of structs for language info
    let msTransalate = Translation()

    weak var delegate: LookupTranslationViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
      //  print ("LookupUP Translation Loaded")
        arrayLangInfo = msTransalate.getTranslationLanguages()
        // MARK: - Setup
       // msTransalate.azureKey = "cb8b61b7e77142288108b771af2f73bf"
        let defaults = UserDefaults.standard
        msTransalate.azureKey  = defaults.object(forKey: "msAzureKeyText") as? String ?? "<requires MS Azure key>"
        msAzureKeyText.stringValue = msTransalate.azureKey!

        let menuFrom = fromLanguage.menu,
                    menuTo = toLanguage.menu
        menuFrom?.removeAllItems()
        menuTo?.removeAllItems()
        for languageKey in arrayLangInfo {  // build menu
            var rowContent = String()
            rowContent = languageKey.nativeName + " (" + languageKey.name + ")"
            menuTo?.addItem(withTitle: rowContent, action: nil, keyEquivalent: "")
        //    if  listExistingLang .contains(languageKey.code) {  // only ilst langues we current have.
                rowContent = languageKey.name + " (" + languageKey.nativeName + ")"
                menuFrom?.addItem(withTitle: rowContent, action: nil, keyEquivalent: "")
          //  }
        }

// restore last selection from default
        let fromLang = defaults.string(forKey: "fromLang") ?? "en"
        setFromLanguage(languageCode: fromLang)

        let toLang = defaults.string(forKey: "toLang") ?? "fr"
        setToLanguage(languageCode: toLang)
        self.window.contentViewController = self

      //  print("restore:", fromLang, toLang)
        if self.dataSource != nil {
            let group = self.dataSource?.getSelectedGroup()
            print(group!.name)
            listExistingLang = self.dataSource!.selectGroupAndGetLanguages(for: group!.name)
            let loctext: LocalizationString  = (self.dataSource?.getLocalization(language: fromLang, row: self.currentRow ))!
            print(loctext)

        }

    }   // end viewDidLoad

func setFromLanguage(languageCode: String) {
        var cnt = 0
        for lang in arrayLangInfo {
            if languageCode == lang.code {
                 fromLanguage.selectItem(at: cnt)
                return
            }
            cnt += 1
        }
    }

    func setToLanguage(languageCode: String) {
           var cnt = 0
           for lang in arrayLangInfo {
               if languageCode == lang.code {
                    toLanguage.selectItem(at: cnt)
                   return
               }
               cnt += 1
           }
       }

    // MARK: - Actions

    @IBAction private func keyChanged(_ sender: Any) {

        msTransalate.azureKey = msAzureKeyText.stringValue
        let defaults = UserDefaults.standard
        defaults.set(msTransalate.azureKey, forKey: "msAzureKeyText")
    }

    // https://docs.microsoft.com/en-us/azure/cognitive-services/translator/reference/v3-0-translate
    @IBAction private func getTranslationBtn(_ sender: Any) {
        let typeOfRequest = "translate"
        var fromLangCode = Int()
        var toLangCode = Int()
        let jsonEncoder = JSONEncoder()

        let text2Translate = textToSubmitTxtView.string   // UITextView!
        if text2Translate.count == 0 {
                  DispatchQueue.main.async {
                      self.textReturnedTxtView.string = "Please enter text to be translated".localized
                  }
                  return
               }
        fromLangCode = self.fromLanguage.indexOfSelectedItem
        toLangCode = self.toLanguage.indexOfSelectedItem
        let selectedFromLangCode = arrayLangInfo[fromLangCode].code
        let selectedToLangCode = arrayLangInfo[toLangCode].code
        print("Translate from:", selectedFromLangCode, "To:", selectedToLangCode, "Text: ", text2Translate)

        var encodeTextSingle = EncodeText()
        var toTranslate = [EncodeText]()
        encodeTextSingle.text = text2Translate
        toTranslate.append(encodeTextSingle)    // add term to translate

        let jsonToTranslate = try? jsonEncoder.encode(toTranslate)  //  Body: [{"text":"Enter Text"}]

        //   let apiURL = "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=" + selectedFromLangCode + "&to=" + selectedToLangCode
        let apiURL = "https://" + host + "/translate?api-version=3.0&from=" + selectedFromLangCode + "&to=" + selectedToLangCode
        let request = msTransalate.setupRequest(apiURL: apiURL, jsonToTranslate: (jsonToTranslate)!)

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { responseData, response, responseError in
                if responseError != nil {  print("this is the error ", responseError!)
                return
                }
                // {"error":{"code":401000,"message":"The request is not authorized because credentials are missing or invalid."}}

                // self.parseJson(jsonData: responseData!, typeOfRequest: typeOfRequest)
                let translatedText = self.msTransalate.parseJson(jsonData: responseData!, typeOfRequest: typeOfRequest)

                DispatchQueue.main.async {  self.textReturnedTxtView.string = translatedText
                }
        } // session
       task.resume()
    }

    // https://docs.microsoft.com/en-us/azure/cognitive-services/translator/reference/v3-0-dictionary-lookup
    @IBAction private func dictionaryLookup(_ sender: Any) {
        let typeOfRequest = "lookup"
        var fromLangCode = Int()
        var toLangCode = Int()

        let text2Translate = textToSubmitTxtView.string   // NSTextView!

        // end values...
        fromLangCode = self.fromLanguage.indexOfSelectedItem
        toLangCode = self.toLanguage.indexOfSelectedItem
        let selectedFromLangCode = arrayLangInfo[fromLangCode].code
        let selectedToLangCode = arrayLangInfo[toLangCode].code

        let defaults = UserDefaults.standard   // save selected lang.
        defaults.set(selectedToLangCode, forKey: "toLang")
        defaults.set(selectedFromLangCode, forKey: "fromLang")

        if text2Translate.count == 0 {
            DispatchQueue.main.async { self.textReturnedTxtView.string = "Please enter text to be looked up in dictionary".localized  }
            return
        }
        print("Dictionary Lookup from:", selectedFromLangCode, "To:", selectedToLangCode, "Text: ", text2Translate)

        // https://api.cognitive.microsofttranslator.com/dictionary/lookup?api-version=3.0
        let apiURL = "https://" + host + "/dictionary/" + typeOfRequest + "?api-version=3.0&from=" + selectedFromLangCode + "&to=" + selectedToLangCode

        let jsonToTranslate = msTransalate.buildJSONDictionaryBody(typeOfRequest: typeOfRequest, lookupText2Translate: text2Translate)
        let request = msTransalate.setupRequest(apiURL: apiURL, jsonToTranslate: (jsonToTranslate)!)
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)

        let task = session.dataTask(with: request) { responseData, response, responseError in

            if responseError != nil { print("this is the error ", responseError!);  return }
            // {"error":{"code":401000,"message":"The request is not authorized because credentials are missing or invalid."}}

             // self.parseJson(jsonData: responseData!, typeOfRequest: typeOfRequest)
             let translatedText = self.msTransalate.parseJson(jsonData: responseData!, typeOfRequest: typeOfRequest)
             DispatchQueue.main.async {
                 self.textReturnedTxtView.string = translatedText
             }
        } // session
        task.resume()
       }    // end dictionaryLookup

    @IBAction private func exampleLookup(_ sender: Any) {
        let typeOfRequest = "examples"
        var fromLangCode = Int()
        var toLangCode = Int()

        let text2Translate = textToSubmitTxtView.string   // UITextView!
        if text2Translate.count == 0 {
            DispatchQueue.main.async {
                self.textReturnedTxtView.string = "Please enter text to look up example usage.".localized
            }
        return
        }

     //   if ( msTransalate.exampleText != text2Translate) {
     //           dictionaryLookup(sender)    // do needed lookup
     //   }
             // end values...
        fromLangCode = self.fromLanguage.indexOfSelectedItem
        toLangCode = self.toLanguage.indexOfSelectedItem
        let selectedFromLangCode = arrayLangInfo[fromLangCode].code
        let selectedToLangCode = arrayLangInfo[toLangCode].code
        print("Look up example from:", selectedFromLangCode, "To:", selectedToLangCode, "Text: ", text2Translate)

        // https://api.cognitive.microsofttranslator.com/dictionary/example?api-version=3.0
        let apiURL = "https://" + host + "/dictionary/" + typeOfRequest + "?api-version=3.0&from=" + selectedFromLangCode + "&to=" + selectedToLangCode

        let jsonToTranslate = msTransalate.buildJSONDictionaryBody(typeOfRequest: typeOfRequest, lookupText2Translate: text2Translate)
        let request = msTransalate.setupRequest(apiURL: apiURL, jsonToTranslate: (jsonToTranslate)!)
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { responseData, response, responseError in

            if responseError != nil {  print("this is the error ", responseError!)
             return
            }
            // {"error":{"code":401000,"message":"The request is not authorized because credentials are missing or invalid."}}

             // self.parseJson(jsonData: responseData!, typeOfRequest: typeOfRequest)
            let translatedText = self.msTransalate.parseJson(jsonData: responseData!, typeOfRequest: typeOfRequest)
            DispatchQueue.main.async { self.textReturnedTxtView.string = translatedText; }
        } // session
        task.resume()
       }

  //  @IBAction private func cancelAction(_ sender: Any) {
  //      delegate?.userDidCancel()
  //  }

    @IBAction private func addAction(_ sender: Any) {
        guard !textReturnedTxtView.string.isEmpty else {
            return
        }
        print("addAction", textReturnedTxtView.string)
        delegate?.userDidAddTranslation(key: textReturnedTxtView.string, message: textToSubmitTxtView.string.isEmpty ? nil : textToSubmitTxtView.string)
    }   // end AddAction
}

// MARK: - NSTextFieldDelegate

extension LookupTranslationViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        self.lookupBtn.isEnabled = !self.textReturnedTxtView.string.isEmpty
    }
}
