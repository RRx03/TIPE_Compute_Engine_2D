
//  Common.h
//  TIPE_Engine_2D
//
//  Created by Roman Roux on 28/08/2023.
//

#ifndef Common_h
#define Common_h
#import <simd/simd.h>


typedef struct {
    simd_uint2 cellCount;
    uint randomSeed;
    float deltaTime;
    float time;
} Uniforms;

typedef struct {
    simd_float4 color;
    uint randomID;
    uint random;
    float density;
    simd_float2 velocityField;
    float userInputDensity;
} Cell;


typedef struct {
    simd_float3 color;
} FluidState;




#endif
