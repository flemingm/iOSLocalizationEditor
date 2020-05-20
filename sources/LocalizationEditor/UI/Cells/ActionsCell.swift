//
//  ActionsCell.swift
//  LocalizationEditor
//
//  Created by Igor Kulman on 05/03/2019.
//  Copyright © 2019 Igor Kulman. All rights reserved.
//

import Cocoa

protocol ActionsCellDelegate: AnyObject {
    func userDidRequestRemoval(of key: String)
    func userDidRequestOpenMSTranslator(of key: String)
    func userDidRequestGetTranslatorInfo(of key: String) -> ([String], Int, LocalizationsDataSource)
}

final class ActionsCell: NSTableCellView {
    // MARK: - Outlets

    @IBOutlet private weak var deleteButton: NSButton!
    @IBOutlet private weak var msAPIlookupButton: NSButton!

    // MARK: - Properties

    static let identifier = "ActionsCell"

    var key: String?
    weak var delegate: ActionsCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        deleteButton.image = NSImage(named: NSImage.stopProgressTemplateName)
        deleteButton.toolTip = "delete".localized
        msAPIlookupButton.toolTip = "Microsoft Translator".localized
    }

    @IBAction private func msAPILookupClicked(_ sender: NSButton) {
          guard let key = key else {
              return
          }
        print("clicked msAPI")
        let viewTrans = LookupTranslationViewController()
        let wcLang = NSWindowController(windowNibName: "LookupTranslationWin", owner: viewTrans)
        wcLang.showWindow(sender)
        var (langList, row, datasrc) = self.delegate!.userDidRequestGetTranslatorInfo(of: key)
        //  delegate?.userDidRequestRemoval(of: key)
        viewTrans.listExistingLang = langList
        viewTrans.dataSource = datasrc
        viewTrans.currentRow = row
      }
    @IBAction private func removalClicked(_ sender: NSButton) {
        guard let key = key else {
            return
        }

        delegate?.userDidRequestRemoval(of: key)
    }
}
