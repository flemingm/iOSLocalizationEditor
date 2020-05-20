# Localization Editor

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Platforms](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
[![Swift Version](https://img.shields.io/badge/Swift-5-F16D39.svg?style=flat)](https://developer.apple.com/swift)
[![Twitter](https://img.shields.io/badge/twitter-@igorkulman-blue.svg)](http://twitter.com/igorkulman)

Simple macOS editor app to help you manage iOS app localizations by allowing you to edit all the translations side by side, highlighting missing translations

![Localization Editor](https://github.com/igorkulman/iOSLocalizationEditor/raw/master/screenshots/editor.png)

## Motivation

Managing localization files (`Localizable.strings`) is a pain, there is no tooling for it. There is no easy way to know what strings are missing or to compare them across languages. 

## What does this tool do?

Start the Localization Editor, choose File | Open folder with localization files and point it to the folder where your localization files are stored. The tool finds all the `Localizable.strings`, detects their language and displays your strings side by side as shown on the screenshot above. You can point it to the root of your project but it will take longer to process. 

All the translations are sorted by their key (shown as first column) and you can see and compare them quickly, you can also see missing translations in any language. 

When you change any of the translations the corresponding `Localizable.strings` gets updated.

New feature added:

Added support to use Microsoft Text transaltion routines. See: https://docs.microsoft.com/en-ca/azure/cognitive-services/Translator/reference/v3-0-reference

Options to translate text, look up dictionary meaning and usage examples

dictionary lookup - Provides alternative translations for a word and a small number of idiomatic phrases. Each translation has a part-of-speech and a list of back-translations. The back-translations enable a user to understand the translation in context. The Dictionary Example operation allows further drill down to see example uses of each translation pair.

Subscribe to Translator or Cognitive Services multi-service in Azure Cognitive Services, and use your subscription key (available in the Azure portal) to authenticate. Interface has place to put the key. It is saved in preferences once enter.  

## Installation

### Homebrew

```bash
brew cask install localizationeditor
```

### Manual

To download and run the app

- Go to [Releases](https://github.com/igorkulman/iOSLocalizationEditor/releases) and download the built app archive **LocalizationEditor.app.zip** from the latest release
- Unzip **LocalizationEditor.app.zip**
- Right click on the extracted **LocalizationEditor.app** and choose Open (just a double-clicking will show a warning because the app is only signed with a development certificate)

## Contributing

All contributions are welcomed, including bug reports and pull requests with new features. Please read [CONTRIBUTING](CONTRIBUTING.md) for more details.

### Localizing the app

The app is currently localized into English and Chinese. If you want to add localization for your language, just translate the [Localizable.strings](https://github.com/igorkulman/iOSLocalizationEditor/blob/master/sources/LocalizationEditor/Resources/en.lproj/Localizable.strings) files. You can use this app do do it!

## Author

- **Igor Kulman** - *Initial work* - igor@kulman.sk

See also the list of [contributors](https://github.com/igorkulman/iOSLocalizationEditor/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
