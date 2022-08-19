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

vertex ColoredVertex vertex_passthrough(Vertex in [[stage_in]],
                                        constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColoredVertex vert;
    vert.position = uniforms.projectionMatrix * float4(in.position, 0, 1);
    vert.color = float4(in.color, 1);
    return vert;
}

fragment float4 fragment_passthrough(ColoredVertex vert [[stage_in]])
{
    return vert.color;
}
