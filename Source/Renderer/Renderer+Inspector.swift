//
//  Renderer+Inspector.swift
//  Instancing
//
//  Created by Reza Ali on 1/21/21.
//  Copyright © 2020 Reza Ali. All rights reserved.
//


import Satin
import Youi

extension Renderer {
    #if os(macOS)
    func setupInspector() {
        var panelOpenStates: [String: Bool] = [:]
        if let inspectorWindow = self.inspectorWindow, let inspector = inspectorWindow.inspectorViewController {
            let panels = inspector.getPanels()
            for panel in panels {
                if let label = panel.parameters?.label {
                    panelOpenStates[label] = panel.open
                }
            }
        }
        
        if inspectorWindow == nil {
            inspectorWindow = InspectorWindow("Inspector")
            inspectorWindow?.setIsVisible(true)
        }
        
        if let inspectorWindow = self.inspectorWindow, let inspectorViewController = inspectorWindow.inspectorViewController {
            if inspectorViewController.getPanels().count > 0 {
                inspectorViewController.removeAllPanels()
            }
            
            // add params here
            inspectorViewController.addPanel(PanelViewController(params.label, parameters: params))
            inspectorViewController.addPanel(PanelViewController(instanceMaterial.label + " Material", parameters: instanceMaterial.parameters))
            
            let panels = inspectorViewController.getPanels()
            for panel in panels {
                if let label = panel.parameters?.label {
                    if let open = panelOpenStates[label] {
                        panel.open = open
                    }
                }
            }
        }
    }
    
    func updateInspector() {
        if _updateInspector {
            DispatchQueue.main.async { [unowned self] in
                self.setupInspector()
            }
            _updateInspector = false
        }
    }
    #endif
}
