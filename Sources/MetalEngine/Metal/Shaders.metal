//
//  Shaders.metal
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

struct ColoredVertex
{
    float4 position [[position]];
    float4 color;
};

vertex ColoredVertex vertex_passthrough(constant float4 *position [[buffer(BufferIndexVertexPositions)]],
                                        constant float4 *color [[buffer(BufferIndexVertexColors)]],
                                        constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                                        uint vid [[vertex_id]])
{
    ColoredVertex vert;
    vert.position = uniforms.projectionMatrix * position[vid];
    vert.color = color[vid];
    return vert;
}

fragment float4 fragment_passthrough(ColoredVertex vert [[stage_in]])
{
    return vert.color;
}
