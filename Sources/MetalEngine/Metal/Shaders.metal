//
//  Shaders.metal
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

struct Vertex {
    float2 position [[attribute(VertexAttrPosition)]];
    float4 color    [[attribute(VertexAttrColor)]];
};

struct ColoredVertex {
    float4 position [[position]];
    float4 color;
    float  point_size [[point_size]];
};

vertex ColoredVertex vertex_2d(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[buffer(BufferIndexUniform)]]) {
    ColoredVertex vert;
    vert.position = uniforms.projectionMatrix * float4(in.position, 0, 1);
    vert.color = in.color;
    vert.point_size = 1 * uniforms.scaleFactor;
    return vert;
}

fragment float4 fragment_passthrough(ColoredVertex vert [[stage_in]]) {
    return vert.color;
}
