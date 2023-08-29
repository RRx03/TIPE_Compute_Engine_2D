import MetalKit


class Renderer: NSObject {
    static var device: MTLDevice!
    static var library: MTLLibrary!
    static var commandQueue: MTLCommandQueue!

    var uniforms = Uniforms(cellCount: [UInt32(commonVariables.cellCount.x), UInt32(commonVariables.cellCount.y)], randomSeed: UInt32.random(in: 0...100000), deltaTime: 0, time: 0)
    
        var computePipelineState: MTLComputePipelineState!
    var initComputePipelineState: MTLComputePipelineState!
    var initPixelsComputePipelineState: MTLComputePipelineState!

    
    var cells : [Cell] = {return Array(repeating: Cell(color: [1, 1, 1, 1], randomID: 0, random: 0, density: 0, velocityField: [0, 0], userInputDensity: 0), count: Int(commonVariables.cellCount.x)*Int(commonVariables.cellCount.y))}()
    var cellsBuffer : MTLBuffer!
    var textureBuffer: MTLTexture!
    var textureBufferDescriptor: MTLTextureDescriptor!
    
    var lastTime: Double = CFAbsoluteTimeGetCurrent()

        
    init(metalView: MTKView) {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue()
        else {
            fatalError("Could not init device or commandQueue. Error Renderer")
        }
        Renderer.device = device
        Renderer.commandQueue = commandQueue
        metalView.device = device
        metalView.framebufferOnly = false
        
        textureBufferDescriptor = MTLTextureDescriptor()
        textureBufferDescriptor.textureType = .type2D
        textureBufferDescriptor.pixelFormat = .bgra8Unorm
        textureBufferDescriptor.width = Int(commonVariables.width*2)
        textureBufferDescriptor.height = Int(commonVariables.height*2)
        textureBufferDescriptor.usage = [.shaderRead, .shaderWrite]
        textureBuffer = device.makeTexture(descriptor: textureBufferDescriptor)
        
        super.init()
        
        let defaultLibrary = device.makeDefaultLibrary()
        let kernelFunction = defaultLibrary?.makeFunction(name: "main_kernel")
        let initKernelFunction = defaultLibrary?.makeFunction(name: "init_Cells")
        let initPixelsFunction = defaultLibrary?.makeFunction(name: "init_Pixels")

        
        do {
            computePipelineState = try device.makeComputePipelineState(function: kernelFunction!)
            initComputePipelineState = try device.makeComputePipelineState(function: initKernelFunction!)
            initPixelsComputePipelineState = try device.makeComputePipelineState(function: initPixelsFunction!)
        } catch {
            fatalError("Failed to init pipelineState")
        }
        
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
        init_Cells()
        
        }
    func init_Cells(){
        cellsBuffer = Renderer.device.makeBuffer(bytes: &cells, length: MemoryLayout<Cell>.stride * cells.count)
        guard
            let commandBuffer: MTLCommandBuffer = Renderer.commandQueue.makeCommandBuffer(),
            let computeEncoder = commandBuffer.makeComputeCommandEncoder()

        else {
            return
        }
        var threadsPerGrid: MTLSize
        var threadsPerThreadgroup: MTLSize
        let w: Int = computePipelineState.threadExecutionWidth
        computeEncoder.setComputePipelineState(initComputePipelineState)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        computeEncoder.setBuffer(cellsBuffer, offset: 0, index: 1)
        threadsPerGrid = MTLSize(width: cells.count, height: 1, depth: 1)
        threadsPerThreadgroup = MTLSize(width: w, height: 1, depth: 1)
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

        
        let h: Int = computePipelineState.maxTotalThreadsPerThreadgroup / w
        computeEncoder.setComputePipelineState(initPixelsComputePipelineState)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        computeEncoder.setTexture(textureBuffer, index: 3)
        computeEncoder.setBuffer(cellsBuffer, offset: 0, index: 1)
        threadsPerGrid = MTLSize(width: textureBuffer.width, height: textureBuffer.height, depth: 1)
        threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        

        
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let commandBuffer: MTLCommandBuffer = Renderer.commandQueue.makeCommandBuffer(),
            let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
            let drawable = view.currentDrawable

        else {
            return
        }
        let currentTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = Float(currentTime - lastTime)
        lastTime = currentTime
        
        uniforms.deltaTime = deltaTime
        uniforms.time += 0.001

        
        var threadsPerGrid: MTLSize
        var threadsPerThreadgroup: MTLSize

        let w: Int = computePipelineState.threadExecutionWidth
        let h: Int = computePipelineState.maxTotalThreadsPerThreadgroup / w
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        computeEncoder.setTexture(drawable.texture, index: 0)
        computeEncoder.setTexture(drawable.texture, index: 1)
        computeEncoder.setTexture(textureBuffer, index: 2)
        computeEncoder.setTexture(textureBuffer, index: 3)
        computeEncoder.setBuffer(cellsBuffer, offset: 0, index: 1)
        threadsPerGrid = MTLSize(width: drawable.texture.width, height: drawable.texture.height, depth: 1)
        threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        computeEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
