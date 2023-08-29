import MetalKit
import MetalPerformanceShaders

class Renderer: NSObject {
    static var device: MTLDevice!
    static var library: MTLLibrary!
    static var commandQueue: MTLCommandQueue!
    
    var uniforms = Uniforms(randomSeed: UInt32.random(in: 0 ... 100000), deltaTime: 0, time: 0)
    
    var randomState: [UInt32] = [0, 0, 0, 0, 0]
    var randomStateBuffer: MTLBuffer!
    
    var draw_PipelineState: MTLComputePipelineState!
    
    var postProcess = PostProcess()
    
    
    var show = true

    
    
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
        
        
        
        super.init()
        
        let defaultLibrary = device.makeDefaultLibrary()
        let draw_function = defaultLibrary?.makeFunction(name: "draw")
        
        do {
            draw_PipelineState = try device.makeComputePipelineState(function: draw_function!)
            
        } catch {
            fatalError("Failed to init pipelineState")
        }
        
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
        randomStateBuffer = Renderer.device.makeBuffer(bytes: &randomState, length: MemoryLayout<UInt32>.stride * randomState.count)
        postProcess.initVal()
    }
}


extension Renderer: MTKViewDelegate {
    func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let commandBuffer: MTLCommandBuffer = Renderer.commandQueue.makeCommandBuffer(),
            let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
            let drawable = view.currentDrawable else { return }

        let currentTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = Float(currentTime - lastTime)
        lastTime = currentTime
        
        uniforms.deltaTime = deltaTime
        uniforms.time += 1
        
        var threadsPerGrid: MTLSize
        var threadsPerThreadgroup: MTLSize
        let w: Int = draw_PipelineState.threadExecutionWidth
        let h: Int = draw_PipelineState.maxTotalThreadsPerThreadgroup / w
        
        computeEncoder.setComputePipelineState(draw_PipelineState)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 11)
        computeEncoder.setBuffer(randomStateBuffer, offset: 0, index: 12)
        computeEncoder.setTexture(drawable.texture, index: 0)
        computeEncoder.setTexture(drawable.texture, index: 1)
        threadsPerGrid = MTLSize(width: drawable.texture.width, height: drawable.texture.height, depth: 1)
        threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
        
        
        if (Int(uniforms.time)%10 == 0){
            show = !show;
        }
        
        if (show){
            
                postProcess.postProcess(view: view, commandBuffer: commandBuffer)

            
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
