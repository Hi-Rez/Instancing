//
//  Renderer+Export.swift
//  Instancing
//
//  Created by Reza Ali on 1/21/21.
//  Copyright © 2020 Reza Ali. All rights reserved.
//

import AppKit
import Satin
import ModelIO

extension Renderer {
    func exportImage() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.nameFieldStringValue = ""
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
        panel.begin { result in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue, let url = panel.url {
                _ = self.exportImage(url)
            }
        }
    }
    
    func exportImage(_ url: URL) -> Bool {
        let tiler = Tiler(renderer: renderer, commandQueue: commandQueue, mtkView: mtkView, scale: exportScaleParam.value)
        return tiler.export(exportURL: url)
    }
}
