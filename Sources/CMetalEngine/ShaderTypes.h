//
//  ShaderTypes.h
//  CMetalEngine
//
//  Licensed under MIT (https://github.com/johnfairh/TMLEngines/blob/main/LICENSE
//

// Types and enum constants shared between Metal shaders and Swift
#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#define METAL(A) A
#else
#import <Foundation/Foundation.h>
#define METAL(A)
#endif

typedef NS_ENUM(NSInteger, BufferIndex)
{
    BufferIndexVertexPositions = 0,
    BufferIndexUniforms        = 1,
};

typedef NS_ENUM(NSInteger, VertexAttr)
{
    VertexAttrPosition = 0,
    VertexAttrColor    = 1,
};

typedef struct
{
    matrix_float4x4 projectionMatrix;
} Uniforms;

typedef struct {
    vector_float2 position METAL([[attribute(VertexAttrPosition)]]);
    vector_float3 color    METAL([[attribute(VertexAttrColor)]]);
} Vertex;

#endif /* ShaderTypes_h */
