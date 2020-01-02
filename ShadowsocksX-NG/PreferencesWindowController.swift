
import Cocoa
import RxCocoa
import RxSwift

class PreferencesWindowController: NSWindowController
    , NSTableViewDataSource, NSTableViewDelegate {
    
    override func windowDidLoad() {
        super.windowDidLoad()

    }
    
    @IBAction func clickBuy(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "http://" + TenonP2pLib.sharedInstance.buy_tenon_ip + "/chongzhi/" + TenonP2pLib.sharedInstance.account_id_)!)
    }
}
