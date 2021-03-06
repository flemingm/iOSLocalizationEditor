//
//  ViewController.swift
//  LocalizationEditor
//
//  Created by Igor Kulman on 30/05/2018.
//  Copyright © 2018 Igor Kulman. All rights reserved.
//  LG Support and MS Translation integration Copyright Mark Fleming, All rights reserved.

import Cocoa
import os
/**
Protocol for announcing changes to the toolbar. Needed because the VC does not have direct access to the toolbar (handled by WindowController)
 */
protocol ViewControllerDelegate: AnyObject {
    /**
     Invoked when localization groups should be set in the toolbar's dropdown list
     */
    func shouldSetLocalizationGroups(groups: [LocalizationGroup])

    /**
     Invoiked when search and filter should be reset in the toolbar
     */
    func shouldResetSearchTermAndFilter()

    /**
     Invoked when localization group should be selected in the toolbar's dropdown list
     */
    func shouldSelectLocalizationGroup(title: String)
}

final class ViewController: NSViewController, XMLParserDelegate {
    enum FixedColumn: String {
        case key
        case actions
    }

    // MARK: - Outlets

    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!

    // MARK: - Properties

    weak var delegate: ViewControllerDelegate?

    private var currentFilter: Filter = .all
    private var currentSearchTerm: String = ""
    private let dataSource = LocalizationsDataSource()
    private var presendedAddViewController: AddViewController?

// XML Parser..
    fileprivate var LGresults: [LocalizationString] = .init()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupData()
    }

     private func openMSTranslator(of key: String) {
        // Apply to missing translations (set filtering?)
        self.dataSource.filter(by: .missing, searchString: self.currentSearchTerm)
        let theGroup: LocalizationGroup = self.dataSource.getSelectedGroup()

        // confirm we have source and trans language and apply to missing.
           let lang = dataSource.selectGroupAndGetLanguages(for: theGroup.name)
           dump(lang)    // list languages loaded for translation.

      //  let translatedCnt = lgparser.applytranslation(theGroup: theGroup, dataSource: self.dataSource)
        // force updated new transaltion to be displayed.
        self.userDidRequestLocalizationGroupChange(group: theGroup.name)
        self.dataSource.filter(by: self.currentFilter, searchString: self.currentSearchTerm)
    }
	// MARK: - XML of Apple Glossary (.lg)
    private func openLGFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true

        openPanel.begin { [unowned self] result -> Void in
            guard result.rawValue == NSApplication.ModalResponse.OK.rawValue else {
                       return
                   }
                   self.progressIndicator.startAnimation(self)

            os_log("\nSelected LG...", type: OSLogType.info)
            // dump(myArray)
            // Apply to missing translations (set filtering?)
            self.dataSource.filter(by: .missing, searchString: self.currentSearchTerm)
            let theGroup: LocalizationGroup = self.dataSource.getSelectedGroup()

            let lgparser = LGParser(urls: openPanel.urls, theTableView: self.tableView )
            do {
                try self.LGresults = lgparser.parse()
            } catch {
               os_log("\n>>> catch LGresults", type: OSLogType.error)
            }

            os_log("\n>>> lgparser %@", type: OSLogType.info, lgparser)
            let translatedCnt = lgparser.applytranslation(theGroup: theGroup, dataSource: self.dataSource)
            os_log("\n>>> translated %d", type: OSLogType.info, translatedCnt)

            self.progressIndicator.stopAnimation(self)

            // force updated new transaltion to be displayed.
            self.userDidRequestLocalizationGroupChange(group: theGroup.name)
            self.dataSource.filter(by: self.currentFilter, searchString: self.currentSearchTerm)
        } // end OpenPanel

    }

    // MARK: - Setup

    private func setupData() {
        let cellIdentifiers = [KeyCell.identifier, LocalizationCell.identifier, ActionsCell.identifier]
        cellIdentifiers.forEach { identifier in
            let cell = NSNib(nibNamed: identifier, bundle: nil)
            tableView.register(cell, forIdentifier: NSUserInterfaceItemIdentifier(rawValue: identifier))
        }

        tableView.delegate = self
        tableView.dataSource = dataSource
        tableView.allowsColumnResizing = true
        tableView.usesAutomaticRowHeights = true

        tableView.selectionHighlightStyle = .none
    }

    private func reloadData(with languages: [String], title: String?) {
        delegate?.shouldResetSearchTermAndFilter()

        let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
        view.window?.title = title.flatMap({ "\(appName) [\($0)]" }) ?? appName

        let columns = tableView.tableColumns
        columns.forEach {
            self.tableView.removeTableColumn($0)
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(FixedColumn.key.rawValue))
        column.title = "key".localized
        tableView.addTableColumn(column)

        languages.forEach { language in
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(language))
            column.title = Flag(languageCode: language).emoji
            column.maxWidth = 460
            column.minWidth = 50
            self.tableView.addTableColumn(column)
        }

        let actionsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(FixedColumn.actions.rawValue))
        actionsColumn.title = "actions".localized
        actionsColumn.maxWidth = 48
        actionsColumn.minWidth = 32
        tableView.addTableColumn(actionsColumn)

        tableView.reloadData()

        // Also resize the columns:
        tableView.sizeToFit()

        // Needed to properly size the actions column
        DispatchQueue.main.async {
            self.tableView.sizeToFit()
            self.tableView.layout()
        }
    }

    private func filter() {
        dataSource.filter(by: currentFilter, searchString: currentSearchTerm)
        tableView.reloadData()
    }

    private func openFolder() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.canChooseFiles = false
        openPanel.begin { [unowned self] result -> Void in
            guard result.rawValue == NSApplication.ModalResponse.OK.rawValue, let url = openPanel.url else {
                return
            }

            self.progressIndicator.startAnimation(self)
            self.dataSource.load(folder: url) { [unowned self] languages, title, localizationFiles in
                self.reloadData(with: languages, title: title)
                self.progressIndicator.stopAnimation(self)

                if let title = title {
                    self.delegate?.shouldSetLocalizationGroups(groups: localizationFiles)
                    self.delegate?.shouldSelectLocalizationGroup(title: title)
                }
            }
        }
    }
}

// MARK: - NSTableViewDelegate

extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier else {
            return nil
        }

        switch identifier.rawValue {
        case FixedColumn.key.rawValue:
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: KeyCell.identifier), owner: self)! as! KeyCell
            cell.key = dataSource.getKey(row: row)
            cell.message = dataSource.getMessage(row: row)
            return cell
        case FixedColumn.actions.rawValue:
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: ActionsCell.identifier), owner: self)! as! ActionsCell
            cell.delegate = self
            cell.key = dataSource.getKey(row: row)
            return cell
        default:
            let language = identifier.rawValue
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: LocalizationCell.identifier), owner: self)! as! LocalizationCell
            cell.delegate = self
            cell.language = language
            cell.value = row < dataSource.numberOfRows(in: tableView) ? dataSource.getLocalization(language: language, row: row) : nil
            return cell
        }
    }
}

// MARK: - LocalizationCellDelegate

extension ViewController: LocalizationCellDelegate {
    func userDidUpdateLocalizationString(language: String, key: String, with value: String, message: String?) {
        dataSource.updateLocalization(language: language, key: key, with: value, message: message)
    }
}

// MARK: - ActionsCellDelegate

extension ViewController: ActionsCellDelegate {
    //  -> (Array, String, String)  List of languages, From, To string.
    func userDidRequestGetGroup(of key: String) -> [String] {
        let theGroup: LocalizationGroup = self.dataSource.getSelectedGroup()
     //   dump(theGroup)
              // confirm we have source and trans language and apply to missing.
       // - Parameter group: group name
        // - Returns: array of languages : Strings
    //    dump(dataSource.getSelectedGroup())
        let lang = dataSource.selectGroupAndGetLanguages(for: theGroup.name)
        dump(lang)    // list languages loaded for translation.
        return lang
    }
    func userDidRequestRemoval(of key: String) {
        dataSource.deleteLocalization(key: key)

        // reload keeping scroll position
        let rect = tableView.visibleRect
        filter()
        tableView.scrollToVisible(rect)
    }
}

// MARK: - WindowControllerToolbarDelegate

extension ViewController: WindowControllerToolbarDelegate {

   func userDidRequestGetTranslatorInfo(of key: String) -> ([String], Int, LocalizationsDataSource) {
       // let row = self.dataSource.getRowForKey(key: key)
        /* localizations: 3 elements
         ▿ EN: 33 translations (/Users/markf/Downloads/iOSLocalizationEditor-master/sources/LocalizationEditor/Resources/en.lproj/Localizable.strings) #1
           - language: "en"
           ▿ translations: 33 elements
             ▿ actions = Actions #2
               - key: "actions"
               - value: "Actions"
               - message: nil
         ...
         */
    //    let rowcnt = dataSource.numberOfRows(in: self.tableView)
        let row = self.dataSource.getRowForKey(key: key)
        let message = self.dataSource.getMessage(row: row!)
        let text: LocalizationString = self.dataSource.getLocalization(language: "en", row: row!)

        print("userDidRequestGetTranslatorInfo", row, "key:", key, "text", text, "message", message)
       // dump(text)
        let theGroup: LocalizationGroup = self.dataSource.getSelectedGroup()
       // dump(theGroup)

             // confirm we have source and trans language and apply to missing.
        let lang = dataSource.selectGroupAndGetLanguages(for: theGroup.name)
       // dump(lang)    // list languages loaded for translation.
     //  for lang =  localizations
    return (lang, row!, self.dataSource)
    }

    func userDidRequestOpenMSTranslator(of key: String) {
        print("videw Ctrl - userDidRequestOpenMSTranslator");
        let theGroup: LocalizationGroup = self.dataSource.getSelectedGroup()
        dump(theGroup)
              // confirm we have source and trans language and apply to missing.
        let lang = dataSource.selectGroupAndGetLanguages(for: theGroup.name)
        dump(lang)    // list languages loaded for translation.
        openMSTranslator( of: key)
    }

    func userDidRequestApplyGlossary() {
		openLGFile()
    }

    /**
     Invoked when user requests adding a new translation
     */
    func userDidRequestAddNewTranslation() {
        let addViewController = storyboard!.instantiateController(withIdentifier: "Add") as! AddViewController
        addViewController.delegate = self
        presendedAddViewController = addViewController
        presentAsSheet(addViewController)
    }

    /**
     Invoked when user requests filter change

     - Parameter filter: new filter setting
     */
    func userDidRequestFilterChange(filter: Filter) {
        guard currentFilter != filter else {
            return
        }

        currentFilter = filter
        self.filter()
    }

    /**
     Invoked when user requests searching

     - Parameter searchTerm: new search term
     */
    func userDidRequestSearch(searchTerm: String) {
        guard currentSearchTerm != searchTerm else {
            return
        }

        currentSearchTerm = searchTerm
        filter()
    }

    /**
     Invoked when user request change of the selected localization group

     - Parameter group: new localization group title
     */
    func userDidRequestLocalizationGroupChange(group: String) {
        let languages = dataSource.selectGroupAndGetLanguages(for: group)
        reloadData(with: languages, title: title)
    }

    /**
     Invoked when user requests opening a folder
     */
    func userDidRequestFolderOpen() {
        openFolder()
    }
}

// MARK: - AddViewControllerDelegate

extension ViewController: AddViewControllerDelegate {
    func userDidCancel() {
        dismiss()
    }

    func userDidAddTranslation(key: String, message: String?) {
        dismiss()

        dataSource.addLocalizationKey(key: key, message: message)
        filter()

        if let row = dataSource.getRowForKey(key: key) {
            DispatchQueue.main.async {
                self.tableView.scrollRowToVisible(row)
            }
        }
    }

    private func dismiss() {
        guard let presendedAddViewController = presendedAddViewController else {
            return
        }

        dismiss(presendedAddViewController)
    }
}
