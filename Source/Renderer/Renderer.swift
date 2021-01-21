//
//  Renderer.swift
//  Instancing
//
//  Created by Reza Ali on 1/21/21.
//  Copyright © 2020 Reza Ali. All rights reserved.
//

import Metal
import MetalKit

import Forge
import Satin
import Youi

class InstanceMaterial: LiveMaterial {}

class Renderer: Forge.Renderer, ObservableObject, MaterialDelegate {
    var assetsURL: URL {
        let url = Bundle.main.resourceURL!
        return url.appendingPathComponent("Assets")
    }
    
    var pipelinesURL: URL {
        assetsURL.appendingPathComponent("Pipelines")
    }
    
    var dataURL: URL {
        assetsURL.appendingPathComponent("Data")
    }
    
    var dataBuffer: MTLBuffer?
    
    lazy var instanceMaterial: InstanceMaterial = {
        let material = InstanceMaterial(pipelinesURL: pipelinesURL)
        material.delegate = self
        material.onBind = { [unowned self] renderEncoder in
            renderEncoder.setVertexBuffer(self.dataBuffer, offset: 0, index: VertexBufferIndex.Custom0.rawValue)
        }
        return material
    }()
    
    var inspectorWindow: InspectorWindow?
    var _updateInspector: Bool = true
    var observers: [NSKeyValueObservation] = []
    
    var exportScaleParam = IntParameter("Export Scale", 4, .inputfield)
    
    lazy var params: ParameterGroup = {
        var params = ParameterGroup("App Controls")
        params.append(exportScaleParam)
        return params
    }()
    
    lazy var mesh: Mesh = {
        Mesh(geometry: QuadGeometry(), material: instanceMaterial)
    }()
    
    lazy var scene: Object = {
        let scene = Object()
        scene.add(mesh)
        return scene
    }()
    
    lazy var context: Context = {
        Context(device, sampleCount, colorPixelFormat, depthPixelFormat, stencilPixelFormat)
    }()
    
    lazy var camera: OrthographicCamera = {
        OrthographicCamera()
    }()
    
    lazy var cameraController: OrthographicCameraController = {
        let controller = OrthographicCameraController(camera: camera, view: mtkView)
        return controller
    }()
    
    lazy var renderer: Satin.Renderer = {
        Satin.Renderer(context: context, scene: scene, camera: camera)
    }()
    
    override func setupMtkView(_ metalKitView: MTKView) {
        metalKitView.isPaused = false
        metalKitView.sampleCount = 1
        metalKitView.depthStencilPixelFormat = .invalid
        metalKitView.preferredFramesPerSecond = 60
    }
    
    override func setup() {
        setupData()
    }
    
    func setupData() {
        var data: [Bool] = []
        do {
            let sequence = try String(contentsOf: dataURL.appendingPathComponent("SARS-CoV-2.txt"))
            for character in sequence {
                switch character {
                case "a":
                    data.append(false)
                    data.append(false)
                case "c":
                    data.append(false)
                    data.append(true)
                case "g":
                    data.append(true)
                    data.append(false)
                case "t":
                    data.append(true)
                    data.append(true)
                default:
                    break
                }
            }
        }
        catch {
            print(error.localizedDescription)
        }
        guard data.count > 0 else { return }
        dataBuffer = context.device.makeBuffer(bytes: &data, length: MemoryLayout<simd_bool>.stride * data.count)
        // data.count/2 because we are representing each character a = 0 c = 1 g = 2 t = 3 using two bools (00, 01, 10, 11)
        mesh.instanceCount = data.count/2
        instanceMaterial.set("Instance Count", Int(data.count/2))
    }
        
    @objc override func updateAppearance() {
        var color = simd_float4(repeating: 1.0)
        if let _ = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
            color = [0.075, 0.075, 0.075, 1.0]
        }
        else {
            color = [0.925, 0.925, 0.925, 1.0]
        }
        instanceMaterial.set("Background Color", color)
        renderer.setClearColor(color)
    }
    
    override func update() {
        #if os(macOS)
            updateInspector()
        #endif
        cameraController.update()
    }
    
    override func draw(_ view: MTKView, _ commandBuffer: MTLCommandBuffer) {
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        renderer.draw(renderPassDescriptor: renderPassDescriptor, commandBuffer: commandBuffer)
    }
    
    override func resize(_ size: (width: Float, height: Float)) {
        let hw = size.width
        let hh = size.height
        camera.update(left: -hw, right: hw, bottom: -hh, top: hh, near: -100.0, far: 100.0)
        
        renderer.resize(size)
        instanceMaterial.set("Resolution", [size.width, size.height, size.width/size.height])
    }
    
    // MARK: - Material Delegate

    func updated(material: Material) {
        print("Material Updated: \(material.label)")
        _updateInspector = true
    }
    
    // MARK: - Key Events

    override func keyDown(with event: NSEvent) {
        if event.characters == "e" {
            openEditor()
        }
    }
}
