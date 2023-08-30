//
//  Common.h
//  TIPE_Engine_2D
//
//  Created by Roman Roux on 28/08/2023.
//

#ifndef Common_h
#define Common_h
#import <simd/simd.h>


typedef struct {
    uint randomSeed;
    float deltaTime;
    float time;
    simd_int2 cellCount;
} Uniforms;

typedef struct {
    float density;
    simd_float2 velocityField;
    uint random;
    uint randomID;
} Cell;

#endif /* Common_h */
