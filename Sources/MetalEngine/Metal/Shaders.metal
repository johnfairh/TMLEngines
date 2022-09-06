//
//  Shaders.metal
//  MetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

struct FlatVertex {
    float2 position [[attribute(VertexAttrPosition)]];
    float4 color    [[attribute(VertexAttrColor)]];
};

struct ColoredVertex {
    float4 position [[position]];
    float4 color;
    float  point_size [[point_size]];
};

struct TexturedVertexIn {
    float2 position    [[attribute(TexturedVertexAttrPosition)]];
    float2 texPosition [[attribute(TexturedVertexAttrTexturePosition)]];
};

struct TexturedVertexOut {
    float4 position [[position]];
    float2 texPosition;
};

vertex ColoredVertex vertex_flat(FlatVertex in [[stage_in]],
                                 constant Uniforms & uniforms [[buffer(BufferIndexUniform)]]) {
    ColoredVertex vert;
    vert.position = uniforms.projectionMatrix * float4(in.position, 0, 1);
    vert.color = in.color;
    vert.point_size = 1 * uniforms.scaleFactor;
    return vert;
}

fragment float4 fragment_flat(ColoredVertex vert [[stage_in]]) {
    return vert.color;
}

vertex TexturedVertexOut vertex_textured(TexturedVertexIn in [[stage_in]],
                                         constant Uniforms & uniforms [[buffer(BufferIndexUniform)]]) {
    TexturedVertexOut vert;
    vert.position = uniforms.projectionMatrix * float4(in.position, 0, 1);
    vert.texPosition = in.texPosition;
    return vert;
}

fragment float4 fragment_textured(TexturedVertexOut in [[stage_in]],
                                  texture2d<float, access::sample> texture [[texture(TextureIndexTexture)]],
                                  sampler sampler [[sampler(SamplerIndexLinear)]]) {
    return texture.sample(sampler, in.texPosition);
}
