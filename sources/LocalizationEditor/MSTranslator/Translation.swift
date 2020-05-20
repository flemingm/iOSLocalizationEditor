//
//  Translation.swift
//
//  Created from TranslatorV3Sample by MSTranslatorMac on 2/15/18.
//  Copyright © 2020 Mark Fleming. All rights reserved.
//
import Foundation

class Translation: NSObject {
    var exampleText = String()      // filled in wiht last lookup for use with Example
    var exampleTranslation = String()
    var dictionaryLangArray = [DictionaryLanguages]()
    var dictionaryLangEach = DictionaryLanguages()
    var dictionaryTranslationTo = DictTranslationsTo()
    let jsonDecoder = JSONDecoder()
    var azureKey: String?
    var debugREST: Bool = false // set to true to display HTTPS Reset API sent / response.
    var secondLanguageArray = [DictTranslationsTo]()

    //*****IBAction
    /*    curl -X POST "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=es" \
           >      -H "Ocp-Apim-Subscription-Key: 75605c0edf924ef197302112e1bbdc2a" \
           >      -H "Ocp-Apim-Subscription-Region:eastus" \
           >      -H "Content-Type: application/json" \
           >      -d "[{'Text':'Hello, what is your name?'}]"
     
           [{"detectedLanguage":{"language":"en","score":1.0},"translations":[{"text":"Hola, ¿cómo te llamas?","to":"es"}]}]
    */

    func parseJsonTranslationAndApply(jsonData: Data, toLang: String) {
         if jsonData.count == 0 { return }

        let str = String(decoding: jsonData, as: UTF8.self)
        if debugREST {  print("Translation List, JSON Response Returned:", str, "\n")  }      // Lookup: [{"text":"exit"}]

        //  URL: https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=en&to=ja
        //  Body: [{"text":"Enter Text"}]
        //  Response:  [{"translations":[{"text":"テキストを入力する","to":"ja"}]}]
        let langTranslations = try? jsonDecoder.decode(Array<TranslationReturnedJson>.self, from: jsonData)
         // print(langTranslations?.count as Any)
        var resultsString = String()
      if (langTranslations) != nil {

        for theTerms in langTranslations! {
            resultsString = (theTerms.translations[0].text) // only show 1st translation
            print(theTerms)
        }

      } else {

        if jsonData.count < 3 {
            resultsString = "No lookup avaialble.".localized
        } else {
            let aError: JSONError = try! jsonDecoder.decode(JSONError.self, from: jsonData)
            print(aError)
            resultsString = "No translation, error:" + aError.error.message
        }
        print(resultsString)
      }
    }

    func applyToMissing(fromLangCode: String, toLangCode: String, keys: [String] ) {
        let jsonEncoder = JSONEncoder()

        let selectedFromLangCode: String = toLangCode // arrayLangInfo[fromLangCode].code
        let selectedToLangCode: String = fromLangCode // arrayLangInfo[toLangCode].code
        print("Translate from:", selectedFromLangCode, "To:", selectedToLangCode)

        var encodeTextSingle = EncodeText()
        var toTranslate = [EncodeText]()

        for theText in keys {
            encodeTextSingle.text = theText
            toTranslate.append(encodeTextSingle)    // add term to translate
        }

        let jsonToTranslate = try? jsonEncoder.encode(toTranslate)  //  Body: [{"text":"Enter Text"}]

        //   let apiURL = "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=" + selectedFromLangCode + "&to=" + selectedToLangCode
        let apiURL = "https://" + host + "/translate?api-version=3.0&from=" + selectedFromLangCode + "&to=" + selectedToLangCode

        let request = self.setupRequest(apiURL: apiURL, jsonToTranslate: (jsonToTranslate)!)

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { responseData, response, responseError in
            if responseError != nil {  print("this is the error ", responseError!)
                return }
                // {"error":{"code":401000,"message":"The request is not authorized because credentials are missing or invalid."}}
            self.parseJsonTranslationAndApply(jsonData: responseData!, toLang: selectedToLangCode)

        } // session
       task.resume()
    }

    // Three API result parsed: "translate", "lookup" and "examples"
    // useful JSON decoder: https://jsonformatter.curiousconcept.com

    // MARK: - Response JSON Parsing of Translation, Dictionation Lookup and Example
/**
       Response JSON Parsing of Translation, Dictionation Lookup and Example

       - Parameter jsonData: JSON Response from API
       - Parameter typeOfRequest: "translate", "lookup" and "examples"
       */
     func parseJson(jsonData: Data, typeOfRequest: String) -> String {
        if jsonData.count < 3 { return "No data returned".localized }
        if debugREST {  let str = String(decoding: jsonData, as: UTF8.self); print("JSON Response Returned:", str, "\n")   }      // Lookup: [{"text":"exit"}]

        var resultsString = "nil"
        if typeOfRequest == "translate" {
            self.exampleText = ""; self.exampleTranslation = "" // reset until dict lookup done again.

            //  URL: https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=en&to=ja
            //  Body: [{"text":"Enter Text"}]
            //  Response:  [{"translations":[{"text":"テキストを入力する","to":"ja"}]}]
            let langTranslations = try? jsonDecoder.decode(Array<TranslationReturnedJson>.self, from: jsonData)
             // print(langTranslations?.count as Any)

              if (langTranslations) != nil {
                  let numberOfTranslations = langTranslations!.count - 1
                  resultsString = (langTranslations?[numberOfTranslations].translations[0].text)! // only show 1st translation
              } else {  let aError: JSONError = try! jsonDecoder.decode(JSONError.self, from: jsonData)
                        print(aError); resultsString = "No translation, error:" + aError.error.message
              }
            return resultsString
        } else // end translate

        if typeOfRequest == "examples" {
            /* Body:  [  {"Text":"fly", "Translation":"volar"} ]
             */
             let dictionaryTranslationsExample = try? jsonDecoder.decode(Array<ResponseJsonExample>.self, from: jsonData)

             if ((dictionaryTranslationsExample != nil)) && dictionaryTranslationsExample?.count != 0 &&
                  dictionaryTranslationsExample?[0].examples.count != 0 {

                let translationSet = dictionaryTranslationsExample?[0]
                resultsString = ""
                for theTerm in translationSet!.examples {
                    resultsString = resultsString.appending("Source word: " + translationSet!.normalizedSource + "\n\tUsage:\t" + theTerm.sourcePrefix + theTerm.sourceTerm + theTerm.sourceSuffix + "\nTarget word: " + translationSet!.normalizedTarget + "\n\tUsage:\t" + theTerm.targetPrefix + theTerm.targetTerm + theTerm.targetSuffix) + "\n\n"
                }
             } else {
                resultsString = "No Examples Found".localized
             }
        } else // end Example

        if typeOfRequest == "lookup" {
            /* Response:
             If the term is not found in the dictionary, the response body includes an empty translations list.
                [ { "normalizedSource":"fly123456", "displaySource":"fly123456",
                     "translations":[] } ]
             
             Term found:
             [ { "normalizedSource":"women",
                   "displaySource":"women",
                   "translations":[
                      { "normalizedTarget":"femmes",
                         "displayTarget":"femmes",
                         "posTag":"NOUN",
                         "confidence":0.7956,
                         "prefixWord":"",
                         "backTranslations":[
                            { "normalizedText":"women",
                               "displayText":"women",
                               "numExamples":15,
                               "frequencyCount":54227
                            },
                           ...
                            { "normalizedText":"ladies",
                               "displayText":"ladies",
                               "numExamples":15,
                               "frequencyCount":909
                            }  ]
                      },
                     ...
                      { "normalizedTarget":"dames",
                         "displayTarget":"dames",
                         "posTag":"NOUN",
                         "confidence":0.0724,
                         "prefixWord":"",
                         "backTranslations":[
                            { "normalizedText":"ladies",
                               "displayText":"ladies",
                               "numExamples":15,
                               "frequencyCount":3121
                            },
                            ...
                         ]
                      } ]
                } ]  */
             let dictionaryTranslationsLookup = try? jsonDecoder.decode(Array<ResponseJsonLookup>.self, from: jsonData)

             if (dictionaryTranslationsLookup != nil) && dictionaryTranslationsLookup?.count != 0 &&
                 dictionaryTranslationsLookup![0].translations.count != 0 {

                self.exampleText = dictionaryTranslationsLookup![0].normalizedSource
                self.exampleTranslation = dictionaryTranslationsLookup![0].translations[0].normalizedTarget

                resultsString = "Source word: " + dictionaryTranslationsLookup![0].normalizedSource + "\n"

                for theTranslation in dictionaryTranslationsLookup![0].translations {
                    resultsString = resultsString.appending("\nTranslations: " + theTranslation.normalizedTarget + "\n" + "\tGrammar: " + theTranslation.posTag + "\n" + "\tConfidence: " + String(theTranslation.confidence)) + "\n"

                   /* backTranslations: A list of "back translations" of the target.
                     For example, source words that the target can translate to. The list is guaranteed to contain the source word that was requested (e.g., if the source word being looked up is "fly", then it is guaranteed that "fly" will be in the backTranslations list). However, it is not guaranteed to be in the first position, and often will not be. Each element of the backTranslations list is an object described by the following properties:
                       * normalizedText: A string giving the normalized form of the source term that is a back-translation of the target. This value should be used as input to lookup examples.
                       * displayText: A string giving the source term that is a back-translation of the target in a form best suited for end-user display.
                       * numExamples: An integer representing the number of examples that are available for this translation pair. Actual examples must be retrieved with a separate call to lookup examples.  */
                   resultsString = resultsString.appending("\tBack translation:") + "\n"
                   for theBackTrans in theTranslation.backTranslations {
                        resultsString = resultsString.appending( "\t\t" + theBackTrans.displayText) + "\n"
                    }   // end backTranslations
                }   // end dictionaryTranslationsLookup
             } else { resultsString = "Term not found".localized }
         }
         return resultsString
    }

    // MARK: - Translation Language list

    func getTranslationLanguages() -> [AllLangDetails] //array of structs for language info
    {
        var arrayLangInfo = [AllLangDetails]() //array of structs for language info
        let translationLangListAddress = "https://" + host + "/languages?api-version=3.0&scope=translation" //"https://api.cognitive.microsofttranslator.com/languages?api-version=3.0&scope=translation"

        let url1 = URL(string: translationLangListAddress)
        let jsonLangData = try! Data(contentsOf: url1!)

        var languages: TranslationLang?
        languages = try! jsonDecoder.decode(TranslationLang.self, from: jsonLangData)
        var eachLangInfo = AllLangDetails(code: " ", name: " ", nativeName: " ", dir: " ") //Use this instance to populate and then append to the array instance

        for languageValues in languages!.translation.values {
            eachLangInfo.name = languageValues.name
            eachLangInfo.nativeName = languageValues.nativeName
            eachLangInfo.dir = languageValues.dir
            arrayLangInfo.append(eachLangInfo)
        //    print(languageValues.name);
        }
        let countOfLanguages = languages?.translation.count
        var counter = 0
        for languageKey in languages!.translation.keys {
            if counter < countOfLanguages! {
                arrayLangInfo[counter].code = languageKey
                counter += 1
            }
    }

        arrayLangInfo.sort(by: { $0.name < $1.name }) //sort the structs based on the language name
        return arrayLangInfo
    }

// MARK: - Dictionary Language list

    func getDictionaryLanguages() {
           let getLanguagesListURLAddress = "https://api.cognitive.microsofttranslator.com/languages?api-version=3.0&scope=dictionary"
       //    print("getLanguages", getLanguagesListURLAddress)
           let url = URL(string: getLanguagesListURLAddress)!
           let jsonData = try! Data(contentsOf: url)
           let languages = try? jsonDecoder.decode(LangDictionary.self, from: jsonData)
           for language in (languages?.dictionary.values)! {
               dictionaryLangEach.langName = language.name
               dictionaryLangEach.langNativeName = language.nativeName
               dictionaryLangEach.langDir = language.dir
              // print("number of scriptLangDetails structs", language.translations.count)

               let countTranslationsArray = language.translations.count
               for index1 in 0...countTranslationsArray - 1 {
                   dictionaryTranslationTo.name = language.translations[index1].name
                   dictionaryTranslationTo.nativeName = language.translations[index1].nativeName
                   dictionaryTranslationTo.dir = language.translations[index1].dir
                   dictionaryTranslationTo.code = language.translations[index1].code

                   dictionaryLangEach.langTranslations.append(dictionaryTranslationTo)
               }
               dictionaryLangArray.append(dictionaryLangEach)
               dictionaryLangEach.langTranslations.removeAll()
           }

           //*****Get lang code(keyvalue) into the struct array
           let countOfLanguages = languages?.dictionary.count
           var counter = 0
           for languageKey in languages!.dictionary.keys {
               if counter < countOfLanguages! {
                dictionaryLangArray[counter].langCode = languageKey; counter += 1
               }
           }
           dictionaryLangArray.sort(by: { $0.langName < $1.langName })
           dictionaryLangEach.langNativeName = "--Select--"
           dictionaryLangArray.insert(dictionaryLangEach, at: 0)

           secondLanguageArray = (dictionaryLangArray.first?.langTranslations)!
       }

//*****IBAction
   /*    curl -X POST "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=es" \
          >      -H "Ocp-Apim-Subscription-Key: 75605c0edf924ef197302112e1bbdc2a" \
          >      -H "Ocp-Apim-Subscription-Region:eastus" \
          >      -H "Content-Type: application/json" \
          >      -d "[{'Text':'Hello, what is your name?'}]"
          [{"detectedLanguage":{"language":"en","score":1.0},"translations":[{"text":"Hola, ¿cómo te llamas?","to":"es"}]}]  */

//  Setup Request and Headers for MS Translations API
//  inout: URL and Body of request.
func setupRequest(apiURL: String, jsonToTranslate: Data) -> URLRequest {
    let url = URL(string: apiURL)
    var request = URLRequest(url: url!)

    request.httpMethod = "POST"
    request.httpBody = jsonToTranslate
    let bodyLen = request.httpBody!.count

    request.addValue(azureKey!, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
    request.addValue(azureRegion, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
    request.addValue(contentType, forHTTPHeaderField: "Content-Type")
    request.addValue(traceID, forHTTPHeaderField: "X-ClientTraceID")
    request.addValue(host, forHTTPHeaderField: "Host")
    request.addValue(String(bodyLen ), forHTTPHeaderField: "Content-Length")

    let str = String(decoding: request.httpBody!, as: UTF8.self)
    if debugREST {
        print("URL:", apiURL, "\nHeaders:", request.allHTTPHeaderFields!, "\nBody:", str, "\n") }
    return request
}

// typeOfRequet = "lookup" and "examples",  Not used for Translation.

func buildJSONDictionaryBody(typeOfRequest: String, lookupText2Translate: String) -> Data? {
    let jsonEncoder = JSONEncoder()
    // Create instances of Structs for encoding
    var encodeLookupTextSingle = EncodeLookupText()
    var encodeLookupText = [EncodeLookupText]()
    var jsonToTranslate: Data? //=  try? jsonEncoder.encode(encodeLookupText)

    if typeOfRequest == "lookup" { //add data to the lookup JSON struct
        /* https://docs.microsoft.com/en-us/azure/cognitive-services/translator/reference/v3-0-dictionary-lookup
         Provides alternative translations for a word and a small number of idiomatic phrases. Each translation has a part-of-speech and a list of back-translations. The back-translations enable a user to understand the translation in context  */
        encodeLookupTextSingle.text = lookupText2Translate
        encodeLookupText.append(encodeLookupTextSingle)
        jsonToTranslate = try! jsonEncoder.encode(encodeLookupText)
    } else // end lookup

    if typeOfRequest == "examples" { //add data to the example JSON struct
        /* https://docs.microsoft.com/en-us/azure/cognitive-services/translator/reference/v3-0-dictionary-examples
         Provides examples that show how terms in the dictionary are used in context. This operation is used in tandem with Dictionary lookup.
         Text: A string specifying the term to lookup. This should be the value of a normalizedText field from the back-translations of a previous Dictionary lookup request. It can also be the value of the normalizedSource field.
         Translation: A string specifying the translated text previously returned by the Dictionary lookup operation. This should be the value from the normalizedTarget field in the translations list of the Dictionary lookup response. The service will return examples for the specific source-target word-pair.
         An example Bodies:  [{"Text":"fly", "Translation":"volar"} ]
                             [{"text":"enter","translation":"entrer"}]
         JSON Response:
            [{"normalizedSource":"enter","normalizedTarget":"entrer",
                "examples":[{"sourcePrefix":"Children can ","sourceTerm":"enter","sourceSuffix":" the data into the computer.",
                            "targetPrefix":"Les enfants peuvent ","targetTerm":"entrer","targetSuffix":" les données dans l’ordinateur."}]}] */
        // Create instances of Structs for encoding
          var encodeExampleTextSingle = EncodeExampleText()
          var encodeExampleText = [EncodeExampleText]()

          // add data (from previous Dictionary lookup request) to the example struct
          encodeExampleTextSingle.text = exampleText
          encodeExampleTextSingle.translation = exampleTranslation
          encodeExampleText.append(encodeExampleTextSingle)
         jsonToTranslate = try! jsonEncoder.encode(encodeExampleText)
    }
    return jsonToTranslate
  }
}
