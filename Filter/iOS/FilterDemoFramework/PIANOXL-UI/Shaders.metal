#include <metal_stdlib>
using namespace metal;

// UTF-8

struct Vertex {
    float2 position [[attribute(0)]];
    float4 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vertexShader(const device Vertex* vertices [[buffer(0)]],
                            uint vid [[vertex_id]]) {
    Vertex in = vertices[vid];
    VertexOut out;
    out.position = float4(in.position.x, in.position.y, 0.0, 1.0);
    out.color = in.color;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
} 