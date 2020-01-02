//
//  TranscationInfoCell.swift
//  TenonVPN-Mac
//
//  Created by friend on 2019/10/10.
//  Copyright © 2019 qiuyuzhou. All rights reserved.
//

import Cocoa

class TranscationInfoCell: NSTableCellView {
    @IBOutlet weak var lbDatatime: NSTextField!
    @IBOutlet weak var lbType: NSTextField!
    @IBOutlet weak var lbAccount: NSTextField!
    @IBOutlet weak var lbAmount: NSTextField!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
