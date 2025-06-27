import MetalKit

// UTF-8

class PianoKeyboardRenderer: NSObject, MTKViewDelegate {
    // MARK: - Properties
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var vertexBuffer: MTLBuffer?
    private var keyRects: [CGRect] = []
    private var activeNotes: Set<Int> = []
    private var keyHighlights: [Int: Float] = [:] // note number -> highlight intensity
    private var lastFrameTime: CFTimeInterval = 0
    
    // MARK: - Constants
    private enum Constants {
        static let fadeOutDuration: Float = 0.3
        static let maxHighlightIntensity: Float = 1.0
        static let minHighlightIntensity: Float = 0.0
        static let whiteKeyColor = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
        static let blackKeyColor = SIMD4<Float>(0.2, 0.2, 0.2, 1.0)
        static let highlightColor = SIMD4<Float>(0.0, 0.7, 1.0, 1.0)
    }
    
    // MARK: - Vertex Data
    private struct Vertex {
        var position: SIMD2<Float>
        var color: SIMD4<Float>
        var highlight: Float
    }
    
    // MARK: - Initialization
    init(metalView: MTKView) {
        self.device = metalView.device!
        self.commandQueue = device.makeCommandQueue()!
        
        // Create render pipeline
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertexShader")!
        let fragmentFunction = library.makeFunction(name: "fragmentShader")!
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        
        self.pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        super.init()
    }
    
    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize if needed
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        if let vertexBuffer = vertexBuffer {
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: keyRects.count * 6)
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: - Public Methods
    func updateKeyRects(_ rects: [CGRect]) {
        keyRects = rects
        updateVertexBuffer()
    }
    
    func setActiveNotes(_ notes: Set<Int>) {
        activeNotes = notes
        updateVertexBuffer()
    }
    
    // MARK: - Private Methods
    private func updateVertexBuffer() {
        var vertices: [Vertex] = []
        
        for (index, rect) in keyRects.enumerated() {
            let isBlackKey = rect.height < rect.width * 2
            let isActive = activeNotes.contains(index)
            
            let color: SIMD4<Float>
            if isActive {
                color = SIMD4<Float>(0.2, 0.6, 1.0, 1.0)
            } else if isBlackKey {
                color = SIMD4<Float>(0.2, 0.2, 0.2, 1.0)
            } else {
                color = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
            }
            
            // Convert rect to normalized device coordinates (-1 to 1)
            let x1 = Float(rect.minX) * 2 - 1
            let x2 = Float(rect.maxX) * 2 - 1
            let y1 = Float(rect.minY) * 2 - 1
            let y2 = Float(rect.maxY) * 2 - 1
            
            let highlight: Float = isActive ? 1.0 : 0.0
            
            // First triangle
            vertices.append(Vertex(position: SIMD2<Float>(x1, y1), color: color, highlight: highlight))
            vertices.append(Vertex(position: SIMD2<Float>(x2, y1), color: color, highlight: highlight))
            vertices.append(Vertex(position: SIMD2<Float>(x1, y2), color: color, highlight: highlight))
            
            // Second triangle
            vertices.append(Vertex(position: SIMD2<Float>(x2, y1), color: color, highlight: highlight))
            vertices.append(Vertex(position: SIMD2<Float>(x2, y2), color: color, highlight: highlight))
            vertices.append(Vertex(position: SIMD2<Float>(x1, y2), color: color, highlight: highlight))
        }
        
        let bufferSize = vertices.count * MemoryLayout<Vertex>.stride
        vertexBuffer = device.makeBuffer(bytes: vertices, length: bufferSize, options: [])
    }
    
    // MARK: - Public Interface
    func setKeyHighlight(note: Int, intensity: Float) {
        keyHighlights[note] = min(max(intensity, Constants.minHighlightIntensity), Constants.maxHighlightIntensity)
    }
}

// MARK: - Metal Shaders
extension PianoKeyboardRenderer {
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    
    struct VertexIn {
        float2 position [[attribute(0)]];
        float4 color [[attribute(1)]];
        float highlight [[attribute(2)]];
    };
    
    struct VertexOut {
        float4 position [[position]];
        float4 color;
        float highlight;
    };
    
    vertex VertexOut vertexShader(const device VertexIn* vertices [[buffer(0)]],
                                 uint vid [[vertex_id]]) {
        VertexOut out;
        out.position = float4(vertices[vid].position, 0.0, 1.0);
        out.color = vertices[vid].color;
        out.highlight = vertices[vid].highlight;
        return out;
    }
    
    fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
        // Add a subtle glow effect based on highlight intensity
        float4 baseColor = in.color;
        float4 glowColor = float4(0.0, 0.7, 1.0, 1.0);
        float glowIntensity = pow(in.highlight, 2.0);
        return mix(baseColor, glowColor, glowIntensity);
    }
    """
}

// MARK: - Vertex Type
// This struct is already defined inside the class, so this is a duplicate.
// struct Vertex {
//     var position: SIMD2<Float>
//     var color: SIMD4<Float>
// } 