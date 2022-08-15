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

typedef struct
{
    matrix_float4x4 projectionMatrix;
} Uniforms;

#endif /* ShaderTypes_h */
