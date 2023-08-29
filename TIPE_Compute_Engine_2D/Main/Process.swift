
import Foundation
import MetalKit
import MetalPerformanceShaders

struct Process {}

struct PostProcess {
    var texture: MTLTexture!
    var finalTexture: MTLTexture!
    
    var textureDescriptor: MTLTextureDescriptor!

    mutating func initVal() {
        textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2D
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = Int(commonVariables.width * 2)
        textureDescriptor.height = Int(commonVariables.height * 2)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        texture = Renderer.device.makeTexture(descriptor: textureDescriptor)
        finalTexture = Renderer.device.makeTexture(descriptor: textureDescriptor)
    }

    mutating func postProcess(view: MTKView, commandBuffer: MTLCommandBuffer) {
        guard
            let drawableTexture =
            view.currentDrawable?.texture else { return }
        let brightness = MPSImageThresholdToZero(
            device: Renderer.device,
            thresholdValue: 0.5,
            linearGrayColorTransform: nil)
        brightness.label = "MPS brightness"
        brightness.encode(
            commandBuffer: commandBuffer,
            sourceTexture: drawableTexture,
            destinationTexture: texture)
        let blur = MPSImageGaussianBlur(
          device: Renderer.device,
          sigma: 9.0)
        blur.label = "MPS blur"
        blur.encode(
          commandBuffer: commandBuffer,
          inPlaceTexture: &texture,
          fallbackCopyAllocator: nil)
        
        finalTexture = texture
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else { return }
        let origin = MTLOrigin(x: 0, y: 0, z: 0)
        let size = MTLSize(
            width: drawableTexture.width,
            height: drawableTexture.height,
            depth: 1)
        blitEncoder.copy(
            from: finalTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: origin,
            sourceSize: size,
            to: drawableTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: origin)
        
        blitEncoder.endEncoding()
    }
}
