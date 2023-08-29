
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
        
        var weight : Float = 0.1
        guard
            let drawableTexture = view.currentDrawable?.texture else { return }
        
        let convolution = MPSImageConvolution(
            device: Renderer.device,
            kernelWidth: 11,
            kernelHeight: 1,
            weights: &weight
            )

        convolution.encode(
            commandBuffer: commandBuffer,
            sourceTexture: drawableTexture,
            destinationTexture: texture
        )
        
        finalTexture = texture
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else { return }
        let origin = MTLOrigin(x: 0, y: 0, z: 0)
        let size = MTLSize(
            width: drawableTexture.width,
            height: drawableTexture.height,
            depth: 1
        )
        blitEncoder.copy(
            from: finalTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: origin,
            sourceSize: size,
            to: drawableTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: origin
        )

        blitEncoder.endEncoding()
    }
}
