//
//  AcountSettingWndController.swift
//  TenonVPN-Mac
//
//  Created by friend on 2019/10/9.
//  Copyright © 2019 qiuyuzhou. All rights reserved.
//

import Cocoa

class AcountSettingWndController: NSWindowController,NSTableViewDelegate,NSTableViewDataSource {

    @IBOutlet weak var prikeyEdit: NSTextField!
    @IBOutlet weak var accountEdit: NSTextField!
    @IBOutlet weak var lbBanlanceTenon: NSTextField!
    @IBOutlet weak var lbBanlanceDorlar: NSTextField!
    @IBOutlet weak var vwTranscationInfo: NSView!
    @IBOutlet weak var scrollview: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    let appDelegate = (NSApplication.shared.delegate) as! AppDelegate
    var transcationList = [TranscationModel]()
    
    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        window?.backgroundColor = NSColor.white
        // MARK:Transcation下的方块view
        vwTranscationInfo.wantsLayer = true
        vwTranscationInfo.layer?.backgroundColor = APP_COLOR.cgColor
        vwTranscationInfo.layer?.masksToBounds = true
        vwTranscationInfo.layer?.cornerRadius = 4
        
        
        var balance = TenonP2pLib.sharedInstance.GetBalance()
        
        if balance == UInt64.max {
            balance = 0
        }
        lbBanlanceTenon.stringValue = String(balance) + " Tenon"
        lbBanlanceDorlar.stringValue = String(format:"%.2f $",Double(balance)*0.002)
        prikeyEdit.stringValue = TenonP2pLib.sharedInstance.private_key_
        accountEdit.stringValue = TenonP2pLib.sharedInstance.account_id_
        tableView.delegate = self
        tableView.dataSource = self
        
        self.tableView.register(NSNib(nibNamed: NSNib.Name(rawValue: "TranscationInfoCell"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: "TranscationInfoCell"))
        tableView.reloadData()
    }
    func refresh() {
        tableView.reloadData()
    }
    func numberOfRows(in tableView: NSTableView) -> Int {
        return transcationList.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 40
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView:TranscationInfoCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "TranscationInfoCell"), owner: self) as! TranscationInfoCell
//        cellView.lbDatatime.stringValue = dataSource[row]
        let model:TranscationModel = self.transcationList[row]
//        tempCell.lbDateTime.text = model.dateTime
//        tempCell.lbType.text = model.type
//        tempCell.lbAccount.text = model.acount
//        tempCell.lbAmount.text = model.amount
        cellView.lbDatatime.stringValue = model.dateTime
        cellView.lbType.stringValue = model.type
        cellView.lbAccount.stringValue = model.acount
        cellView.lbAmount.stringValue = model.amount
        return cellView
    }
    
    @IBAction func clickBue(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "http://" + TenonP2pLib.sharedInstance.buy_tenon_ip + "/chongzhi/" + TenonP2pLib.sharedInstance.account_id_)!)
    }
    
    @IBAction func clickCopyPrivateKey(_ sender: Any) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        pasteboard.setString(TenonP2pLib.sharedInstance.private_key_, forType: NSPasteboard.PasteboardType.string)
    }
    
    func dialogOKCancel(question: String, text: String) -> Bool {
        let alert: NSAlert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let res = alert.runModal()
        if res == NSApplication.ModalResponse.alertFirstButtonReturn {
            return true
        }
        return false
    }
    
    @IBAction func clickPastePrivateKey(_ sender: Any) {
        let ss: String = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string) ?? ""
        if ss == TenonP2pLib.sharedInstance.private_key_ {
            return
        }
        
        if ss.count != 64 {
            _ = dialogOKCancel(question: "", text: "invalid private key.".localized)
            return
        }
        
        if !TenonP2pLib.sharedInstance.SavePrivateKey(prikey_in: ss) {
            _ = dialogOKCancel(question: "", text: "Set up to 3 private keys.".localized)
            return
        }
        
        if !TenonP2pLib.sharedInstance.ResetPrivateKey(prikey: ss) {
            _ = dialogOKCancel(question: "", text: "invalid private key.".localized)
            return
        }
        
        _ = dialogOKCancel(question: "", text: "after success reset private key, must restart program.".localized)
        UserDefaults.standard.set(false, forKey: "ShadowsocksOn")
        let use_st: Int32 = 1
        SyncSSLocal(choosed_country: TenonP2pLib.sharedInstance.choosed_country, local_country: TenonP2pLib.sharedInstance.local_country, smart_route:use_st)
        ProxyConfHelper.disableProxy()
         _exit(0)
    }
    
    @IBAction func clickCopyAccountId(_ sender: Any) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        pasteboard.setString(TenonP2pLib.sharedInstance.account_id_, forType: NSPasteboard.PasteboardType.string)
        
    }
}
