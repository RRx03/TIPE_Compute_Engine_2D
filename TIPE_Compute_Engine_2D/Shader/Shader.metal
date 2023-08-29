

#include <metal_stdlib>
#include "../Common.h"
using namespace metal;

#define twoPI (3.1415 * 2)
#define PI (3.1415)



#define diff (100)
#define smokePatchCount (10)
#define velocityPatch (2)
#define velocityMag (100)

float random(device uint *state, uint offset = 2345678)
{
    *state = *state * (*state + offset * 2) * (*state + offset * 3456) * (*state + 567890) + offset;
    return *state / 4294967295.0;
}

float noise(uint2 position, device uint *state, float2 textureSize, uint2 cellCount, int n = 1, float time = 1, bool inverted = true)
{
    float2 normalizedId = float2(position.x / textureSize.x, position.y / textureSize.y);
    uint2 CellID = uint2(floor(normalizedId * float2(cellCount)));
    float2 innerCellID = fract(normalizedId * float2(cellCount));
    
    float2 gradientVectors[4];
    float2 distanceVectors[4];
    float influenceValues[4];

    for (int i = 0; i < 4; i++)
    {
        uint2 relativeCoordinate;
        switch (i)
        {
        case 0: relativeCoordinate = uint2(0, 0); break;
        case 1: relativeCoordinate = uint2(1, 0); break;
        case 2: relativeCoordinate = uint2(0, 1); break;
        case 3: relativeCoordinate = uint2(1, 1); break;
        }
        uint2 newPosition = CellID + relativeCoordinate;
        float2 distanceVector = innerCellID - float2(relativeCoordinate);
        *state = newPosition.x + newPosition.y * cellCount.x + floor(time)*cellCount.x*cellCount.y;
        for(int i = 1; i < n ; i++){
            random(state);
        }
        float2 currentGradientVector = 2 * float2(random(state), random(state)) - 1;
        *state = newPosition.x + newPosition.y * cellCount.x + (floor(time) + 1)*cellCount.x*cellCount.y;
        for(int i = 1; i < n ; i++){
            random(state);
        }
        float2 newGradientVector = 2 * float2(random(state), random(state)) - 1;
        
        float2 gradientVector = (1-fract(time))*currentGradientVector + fract(time)*newGradientVector;
        gradientVectors[i] = gradientVector;
        distanceVectors[i] = distanceVector;
        influenceValues[i] = (1 + dot(gradientVector, distanceVector)) / 2;
    }
    float2 u = float2(innerCellID);
    float2 interpolator = 6 * pow(u, 5) - 15 * pow(u, 4) + 10 * pow(u, 3);
    float result = (1 - interpolator.y) * (1 - interpolator.x) * influenceValues[0] + (1 - interpolator.y) * interpolator.x * influenceValues[1] + interpolator.y * (1 - interpolator.x) * influenceValues[2] + interpolator.x * interpolator.y * influenceValues[3];
    
    return inverted ? 1-result : result;
    

}

kernel void init_Cells(device Cell *cells [[buffer(1)]],
                       constant Uniforms &uniforms [[buffer(11)]],
                       uint id [[thread_position_in_grid]])

{
    
    
    uint2 CellID = uint2(id % uniforms.cellCount.x, id / uniforms.cellCount.x);
    device uint *state = &cells[id].random;
    *state = id;
    random(state);
    device uint *stateID = &cells[id].randomID;
    *stateID = *state;
    *state = id;

}

kernel void init_Pixels(texture2d<half, access::write> textureBufferOut [[texture(3)]],
                        device Cell *cells [[buffer(1)]],
                        constant Uniforms &uniforms [[buffer(11)]],
                        uint2 textureID [[thread_position_in_grid]])

{
    
#define id(i, j) (i + uniforms.cellCount.x * (j))



    float2 textureSize = float2(textureBufferOut.get_width(), textureBufferOut.get_height());
    float2 normalizedId = float2(textureID.x / textureSize.x, textureID.y / textureSize.y);
    int2 CellID = int2(floor(normalizedId * float2(uniforms.cellCount)));
    float2 innerCellID = fract(normalizedId * float2(uniforms.cellCount));
    Cell cell = cells[id(CellID.x, CellID.y)];
    device uint *state = &cells[id(CellID.x, CellID.y)].random;
    device uint *stateID = &cells[id(CellID.x, CellID.y)].randomID;
    
    
    cell.density = noise(textureID, state, textureSize, uint2(smokePatchCount, smokePatchCount));
    
    

    uint stateSave = *state;
    uint stateIDSave = *stateID;
    cells[id(CellID.x, CellID.y)] = cell;
    *state = stateSave;
    *stateID = stateIDSave;
    
}


kernel void main_kernel(texture2d<half, access::read> textureIn [[texture(1)]],
                        texture2d<half, access::write> textureOut [[texture(0)]],
                        texture2d<half, access::read> textureBufferIn [[texture(2)]],
                        texture2d<half, access::write> textureBufferOut [[texture(3)]],
                        device Cell *cells [[buffer(1)]],
                        constant Uniforms &uniforms [[buffer(11)]],
                        uint2 textureID [[thread_position_in_grid]])

{

#define id(i, j) (i + uniforms.cellCount.x * (j))
#define a (diff * uniforms.deltaTime)
    float2 textureSize = float2(textureOut.get_width(), textureOut.get_height());
    float2 normalizedId = float2(textureID.x / textureSize.x, textureID.y / textureSize.y);
    int2 CellID = int2(floor(normalizedId * float2(uniforms.cellCount)));
    float2 innerCellID = fract(normalizedId * float2(uniforms.cellCount));
    Cell cell = cells[id(CellID.x, CellID.y)];
    device uint *state = &cells[id(CellID.x, CellID.y)].random;
    device uint *stateID = &cells[id(CellID.x, CellID.y)].randomID;
    
    Cell Neighboors[4];
    for (int i = 0; i < 4; i++){
        int2 relativeCoordinate;
        switch (i)
        {
            case 0: relativeCoordinate = int2(1, 0); break;
            case 1: relativeCoordinate = int2(-1, 0); break;
            case 2: relativeCoordinate = int2(0, 1); break;
            case 3: relativeCoordinate = int2(0, -1); break; //faire transfert
        }
        int2 neighboorID = CellID+relativeCoordinate;
        if (neighboorID.x == 0 && i == 1) {
            neighboorID.x = uniforms.cellCount.x-1;
        }else if(neighboorID.x == int(uniforms.cellCount.x-1) && i == 0){
            neighboorID.x = 0;
        }
        if (neighboorID.y == 0 && i == 3) {
            neighboorID.y = uniforms.cellCount.y-1;
        }else if(neighboorID.y == int(uniforms.cellCount.y-1) && i == 2){
            neighboorID.y = 0;
        }
        Neighboors[i] = cells[id(neighboorID.x, neighboorID.y)];
        
    }
    
    
    
    float angle = noise(textureID, state, textureSize, uint2(velocityPatch), 2, uniforms.time) * 2 *twoPI;
    float2 velocityVector = float2(cos(angle), sin(angle));
    cell.velocityField = velocityVector*velocityMag;
    
    cell.density = (cell.density + a * (Neighboors[0].density + Neighboors[1].density + Neighboors[2].density + Neighboors[3].density)) / (1 + 4 * a);

    
    float x, y;
    x = CellID.x-uniforms.deltaTime*cell.velocityField.x;
    y = CellID.y-uniforms.deltaTime*cell.velocityField.y;
    if (x < 0.5) x=0.5;
    if (x > uniforms.cellCount.x+0.5) x=uniforms.cellCount.x+0.5;
    int i0 = int(x);
    int i1 = i0+1;
    if (y<0.5) y=0.5;
    if (y> uniforms.cellCount.y+0.5) y=uniforms.cellCount.y+0.5;
    int j0 = int(y);
    int j1 = j0+1;
    float s1 = x-i0;
    float s0 = 1-s1;
    float t1 = y-j0;
    float t0 = 1-t1;
    cell.density = s0*(t0 * cells[id(i0,j0)].density + t1*cells[id(i0,j1)].density)+s1*(t0*cells[id(i1,j0)].density+t1*cells[id(i1,j1)].density);
    
    
    
    
    
    textureOut.write(half4(cell.density), textureID);
//    textureOut.write(half4(velocityVector.x, velocityVector.y, 0, 1), textureID);
    uint stateSave = *state;
    uint stateIDSave = *stateID;
    cells[id(CellID.x, CellID.y)] = cell;
    *state = stateSave;
    *stateID = stateIDSave;
    
}
