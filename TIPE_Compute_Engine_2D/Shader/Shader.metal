

#include <metal_stdlib>
#include "../Common.h"
using namespace metal;



float random(device uint *state) {
    
    *state = *state * (*state + 973654) * (*state + 577872) * (*state + 398327) + 2345678;
    return *state / 4294967295.0;
}

float noise(uint2 position, device uint *state, float2 textureSize, uint2 cellCount, int n = 1, float time = 1, bool inverted = true) {
    
    float2 normalizedId = float2(position.x / textureSize.x, position.y / textureSize.y);
    uint2 CellID = uint2(floor(normalizedId * float2(cellCount)));
    float2 innerCellID = fract(normalizedId * float2(cellCount));

    float timeSlice = fract(time);
    int timeOffset = floor(time);

    float2 gradientVectors[8];
    float2 distanceVectors[8];
    float influenceValues[8];

    for (int i = 0; i < 4; i++)
    {
        uint2 relativeCoordinate;
        switch (i)
        {

        case 0:
            relativeCoordinate = uint2(0, 0);
            break;
        case 1:
            relativeCoordinate = uint2(1, 0);
            break;
        case 2:
            relativeCoordinate = uint2(0, 1);
            break;
        case 3:
            relativeCoordinate = uint2(1, 1);
            break;
        }
        uint2 newPosition = CellID + relativeCoordinate;
        float2 distanceVector = innerCellID - float2(relativeCoordinate);
        *state = newPosition.x + newPosition.y * cellCount.x + floor(time) * cellCount.x * cellCount.y;
        for (int i = 1; i < n; i++)
        {
            random(state);
        }
        float2 currentGradientVector = 2 * float2(random(state), random(state)) - 1;
        *state = newPosition.x + newPosition.y * cellCount.x + (floor(time) + 1) * cellCount.x * cellCount.y;
        for (int i = 1; i < n; i++)
        {
            random(state);
        }
        float2 newGradientVector = 2 * float2(random(state), random(state)) - 1;

        float2 gradientVector = (1 - fract(time)) * currentGradientVector + fract(time) * newGradientVector;
        gradientVectors[i] = gradientVector;
        distanceVectors[i] = distanceVector;
        influenceValues[i] = (1 + dot(gradientVector, distanceVector)) / 2;
    }
    float2 u = float2(innerCellID);
    float2 interpolator = 6 * pow(u, 5) - 15 * pow(u, 4) + 10 * pow(u, 3);
    float result = (1 - interpolator.y) * (1 - interpolator.x) * influenceValues[0] + (1 - interpolator.y) * interpolator.x * influenceValues[1] + interpolator.y * (1 - interpolator.x) * influenceValues[2] + interpolator.x * interpolator.y * influenceValues[3];

    return inverted ? 1 - result : result;
}

kernel void draw(texture2d<float, access::read> drawableIn [[texture(0)]],
                 texture2d<float, access::write> drawableOut [[texture(1)]],
                 constant Uniforms &uniforms [[buffer(11)]],
                 device uint *randomState [[buffer(12)]],
                 uint2 textureID [[thread_position_in_grid]])
{
    device uint *state = &randomState[0];
    *state = textureID.x + drawableOut.get_width()*textureID.y;
    drawableOut.write(float4(noise(textureID, state, float2(drawableOut.get_width(), drawableOut.get_height()), uint2(10, 10))), textureID);
    
    
    
}
