//
//  Tiler.swift
//  Instancing
//
//  Created by Reza Ali on 1/21/21.
//  Copyright © 2020 Reza Ali. All rights reserved.
//

import Accelerate
import Metal
import MetalKit
#if os(iOS)
import MobileCoreServices
#endif

import Forge
import Satin

class Tiler {
    weak var mtkView: MTKView?
    weak var renderer: Satin.Renderer?
    weak var commandQueue: MTLCommandQueue?
    
    var texture: MTLTexture?
    var cgContext: CGContext?
    var scale: Int
    
    // For Orthographic Camera
    var _left: Float = 0.0
    var _right: Float = 0.0
    var _top: Float = 0.0
    var _bottom: Float = 0.0
    
    init(renderer: Satin.Renderer, commandQueue: MTLCommandQueue, mtkView: MTKView, scale: Int) {
        self.renderer = renderer
        self.commandQueue = commandQueue
        self.mtkView = mtkView
        self.scale = scale
        
        if let camera = renderer.camera as? OrthographicCamera {
            _left = camera.left
            _right = camera.right
            _top = camera.top
            _bottom = camera.bottom
        }
        
        if let device = mtkView.device, mtkView.drawableSize.width > 1, mtkView.drawableSize.height > 1 {
            let descriptor = MTLTextureDescriptor()
            descriptor.pixelFormat = mtkView.colorPixelFormat
            descriptor.width = Int(mtkView.drawableSize.width)
            descriptor.height = Int(mtkView.drawableSize.height)
            descriptor.sampleCount = 1
            descriptor.textureType = .type2D
            descriptor.usage = [.renderTarget]
            #if os(iOS)
            descriptor.storageMode = .shared
            descriptor.resourceOptions = .storageModeShared
            #elseif os(macOS)
            descriptor.storageMode = .managed
            descriptor.resourceOptions = .storageModeManaged
            #endif
            texture = device.makeTexture(descriptor: descriptor)
        }
                        
        let width = Int(mtkView.drawableSize.width)
        let height = Int(mtkView.drawableSize.height)
        let pixelByteCount = 4 * MemoryLayout<UInt8>.size
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue + CGImageAlphaInfo.premultipliedFirst.rawValue
        
        cgContext = CGContext(data: nil,
                              width: width * scale,
                              height: height * scale,
                              bitsPerComponent: 8,
                              bytesPerRow: scale * width * pixelByteCount,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: bitmapInfo)
    }
    
    public func export(exportURL: URL) -> Bool {
        guard let renderer = self.renderer, let commandQueue = self.commandQueue, let texture = self.texture else { return false }
        let limit = scale * scale
        
        let camera = renderer.camera
        for i in 0 ..< limit {
            updateProjection(camera, i)
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return false }
            renderer.draw(renderPassDescriptor: MTLRenderPassDescriptor(), commandBuffer: commandBuffer, renderTarget: texture)
            if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
                #if os(macOS)
                blitEncoder.synchronize(resource: texture)
                #endif
                blitEncoder.optimizeContentsForCPUAccess(texture: texture)
                blitEncoder.endEncoding()
            }
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            exportTexture(i)
        }
        
        if let cgContext = self.cgContext, let render = cgContext.makeImage(), let renderDestination = CGImageDestinationCreateWithURL(exportURL as CFURL, getExtension(exportURL), 1, nil) {
            CGImageDestinationAddImage(renderDestination, render, nil)
            CGImageDestinationFinalize(renderDestination)
        }
                
        
        
        if let orthographicCamera = camera as? OrthographicCamera {
            orthographicCamera.update(left: _left, right: _right, bottom: _bottom, top: _top)
        }
        else {
            camera.updateProjectionMatrix = true
        }
        
        return true
    }
    
    private func updateProjection(_ camera: Camera, _ i: Int) {
        let scalef = Float(scale)
        let x: Int = i % scale
        let y: Int = i / scale
        let xf = Float(x)
        let yf = Float(y)
        
        if let camera = camera as? PerspectiveCamera {
            let aspect = camera.aspect
            let top: Float = camera.near * tan(degToRad(camera.fov * 0.5))
            let bottom: Float = -top
            let right: Float = top * aspect
            let left: Float = -right
            
            let width = right - left
            let height = top - bottom
            
            let widthInc = width / scalef
            let heightInc = height / scalef
                                
            let l: Float = left + xf * widthInc
            let r: Float = l + widthInc
            let b: Float = bottom + yf * heightInc
            let t: Float = b + heightInc
            
            camera.projectionMatrix = frustum(l, r, b, t, camera.near, camera.far)
        }
        else if let camera = camera as? OrthographicCamera {
            let width = _right - _left
            let height = _top - _bottom
            
            let widthInc = width / scalef
            let heightInc = height / scalef
                                
            let l: Float = _left + xf * widthInc
            let r: Float = l + widthInc
            let b: Float = _bottom + yf * heightInc
            let t: Float = b + heightInc
            
            camera.update(left: l, right: r, bottom: b, top: t)
        }
    }
    
    private func getExtension(_ url: URL) -> CFString {
        var ext: CFString
        switch url.pathExtension.lowercased() {
        case "png":
            ext = kUTTypePNG
        case "tif":
            ext = kUTTypeTIFF
        case "tiff":
            ext = kUTTypeTIFF
        case "jpg":
            ext = kUTTypeJPEG
        case "jpeg":
            ext = kUTTypeJPEG2000
        case "bmp":
            ext = kUTTypeBMP
        default:
            ext = kUTTypePNG
        }
        return ext
    }
    
    private func exportTexture(_ i: Int) {
        if let texture = self.texture, let image = exportImage(texture), let cgContext = self.cgContext, let mtkView = self.mtkView {
            let width = Int(mtkView.drawableSize.width)
            let height = Int(mtkView.drawableSize.height)
            let x: Int = i % scale
            let y: Int = i / scale
            cgContext.draw(image, in: CGRect(x: x * width, y: y * height, width: width, height: height))
        }
    }
    
    func swizzleBGRA8toRGBA8(_ bytes: UnsafeMutableRawPointer, width: Int, height: Int) {
        var sourceBuffer = vImage_Buffer(data: bytes,
                                         height: vImagePixelCount(height),
                                         width: vImagePixelCount(width),
                                         rowBytes: width * 4)
        
        var destBuffer = vImage_Buffer(data: bytes,
                                       height: vImagePixelCount(height),
                                       width: vImagePixelCount(width),
                                       rowBytes: width * 4)
        
        var swizzleMask: [UInt8] = [0, 1, 2, 3] // BGRA -> RGBA
        
        let result = vImagePermuteChannels_ARGB8888(&sourceBuffer, &destBuffer, &swizzleMask, vImage_Flags(kvImageNoFlags))
        
        if result != kvImageNoError {
            print("vImagePermuteChannels_ARGB8888 failed")
        }
    }
    
    private func exportImage(_ texture: MTLTexture?) -> CGImage? {
        if let colorTexture = texture {
            let width = colorTexture.width
            let height = colorTexture.height
            let pixelByteCount = 4 * MemoryLayout<UInt8>.size
            let imageBytesPerRow = width * pixelByteCount
            let imageByteCount = imageBytesPerRow * height
            let imageBytes = UnsafeMutableRawPointer.allocate(byteCount: imageByteCount, alignment: pixelByteCount)
            
            defer {
                imageBytes.deallocate()
            }
            
            colorTexture.getBytes(imageBytes, bytesPerRow: imageBytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            
            swizzleBGRA8toRGBA8(imageBytes, width: width, height: height)
            
            let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue + CGImageAlphaInfo.premultipliedFirst.rawValue
            guard let bitmapContext = CGContext(data: nil,
                                                width: width,
                                                height: height,
                                                bitsPerComponent: 8,
                                                bytesPerRow: imageBytesPerRow,
                                                space: CGColorSpaceCreateDeviceRGB(),
                                                bitmapInfo: bitmapInfo) else { return nil }
            
            bitmapContext.data?.copyMemory(from: imageBytes, byteCount: imageByteCount)
            return bitmapContext.makeImage()
        }
        return nil
    }
}
