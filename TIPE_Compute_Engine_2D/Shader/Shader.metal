

#include <metal_stdlib>
#include "../Common.h"
using namespace metal;


kernel void gradientX(texture2d<float, access::read> inputTexture [[texture(0)]],
                      texture2d<float, access::write> outputTexture [[texture(1)]],
                      uint2 gid [[thread_position_in_grid]]) {
    const sampler s(coord::normalized, address::clamp_to_edge, filter::linear);

    float2 gradientX = convolve_gradient_x(inputTexture, s, gid); // A corriger
    outputTexture.write(gradientX.x, gid);
}

kernel void gradientY(texture2d<float, access::read> inputTexture [[texture(0)]],
                      texture2d<float, access::write> outputTexture [[texture(1)]],
                      uint2 gid [[thread_position_in_grid]]) {
    const sampler s(coord::normalized, address::clamp_to_edge, filter::linear);

    float2 gradientY = convolve_gradient_y(inputTexture, s, gid);
    outputTexture.write(gradientY.y, gid);
}
