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
#else
#import <Foundation/Foundation.h>
#endif

typedef NS_ENUM(NSInteger, BufferIndex) {
    BufferIndexVertex  = 0,
    BufferIndexUniform = 1,
};

typedef NS_ENUM(NSInteger, VertexAttr) {
    VertexAttrPosition = 0,
    VertexAttrColor    = 1,
};

typedef NS_ENUM(NSInteger, TexturedVertexAttr) {
    TexturedVertexAttrPosition = 0,
    TexturedVertexAttrTexturePosition = 1,
};

typedef NS_ENUM(NSInteger, TextureIndex) {
    TextureIndexTexture = 0,
};

typedef NS_ENUM(NSInteger, SamplerIndex) {
    SamplerIndexLinear = 0,
};

typedef struct {
    matrix_float4x4 projectionMatrix;
    float           scaleFactor;
} Uniforms;

#endif /* ShaderTypes_h */
