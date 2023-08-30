

#include <metal_stdlib>
#include "../Common.h"
using namespace metal;

#define twoPI (3.1415 * 2)
#define PI (3.1415)


#define velocityMag (1)
#define diff (1)
#define smokePatchCount (10)
#define velocityPatch (2)


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
#define idTwo(i) (i.x + uniforms.cellCount.x * (i.y))



    float2 textureSize = float2(textureBufferOut.get_width(), textureBufferOut.get_height());
    float2 normalizedId = float2(textureID.x / textureSize.x, textureID.y / textureSize.y);
    int2 CellID = int2(floor(normalizedId * float2(uniforms.cellCount)));
    float2 innerCellID = fract(normalizedId * float2(uniforms.cellCount));
    Cell cell = cells[id(CellID.x, CellID.y)];
    device uint *state = &cells[id(CellID.x, CellID.y)].random;
    *state = idTwo(CellID);
    device uint *stateID = &cells[id(CellID.x, CellID.y)].randomID;
    cell.density = 0;
    
    float angleValue = noise(textureID, state, float2(uniforms.cellCount), uint2(velocityPatch))*twoPI*2;
    cell.velocityField = float2(cos(angleValue), sin(angleValue));
    

    
    uint stateSave = *state;
    uint stateIDSave = *stateID;
    cells[id(CellID.x, CellID.y)] = cell;
    *state = stateSave;
    *stateID = stateIDSave;
    
}

int2 coordinatesCorrection(int2 coordinates, int2 textureSize){
    return int2(((coordinates%textureSize)+textureSize)%textureSize);
}

int2 cellIDCorrection (int2 CellID, int2 cellCount){
    return int2(((CellID%cellCount)+cellCount)%cellCount);
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
#define idTwo(i) (i.x + uniforms.cellCount.x * (i.y))
    
    
    float2 textureSize = float2(textureOut.get_width(), textureOut.get_height());
    float2 normalizedId = float2(textureID.x / textureSize.x, textureID.y / textureSize.y);
    int2 CellID = int2(floor(normalizedId * float2(uniforms.cellCount)));
    float2 CellSize = float2(float2(textureSize)/float2(uniforms.cellCount));
    float2 innerCellID = fract(normalizedId * float2(uniforms.cellCount));
    Cell cell = cells[id(CellID.x, CellID.y)];
    device uint *state = &cells[id(CellID.x, CellID.y)].random;
    device uint *stateID = &cells[id(CellID.x, CellID.y)].randomID;
    
    Cell Neighboors[4];
    
    float2 pointOrigin = float2(CellID)+0.5;
    int2 pointArrow = coordinatesCorrection(int2((pointOrigin-cell.velocityField*velocityMag)*CellSize), int2(textureSize));
    float2 pointArrowNormalised = float2(pointArrow)/textureSize;
    float2 pointInnerCell =  fract(pointArrowNormalised * float2(uniforms.cellCount));
    float2 pointInnerCellNormalised = float2(0, 0);

    int2 CellIDs[4];
    
    CellIDs[0] = int2(floor(pointArrowNormalised * float2(uniforms.cellCount)));
    
    int2 relativePointCoord = int2(0, 0);
    if(pointInnerCell.x > 0.5){
        relativePointCoord.x = 1;
        CellIDs[1] = cellIDCorrection(CellIDs[0] + int2(1, 0), int2(uniforms.cellCount));
        pointInnerCellNormalised.x = pointInnerCell.x-0.5;
    }else if(pointInnerCell.x < 0.5){
        relativePointCoord.x = -1;
        CellIDs[1] = cellIDCorrection(CellIDs[0] + int2(-1, 0), int2(uniforms.cellCount));
        pointInnerCellNormalised.x = 0.5-pointInnerCell.x;

    }else {
        relativePointCoord.x = 0;
        CellIDs[1] = CellIDs[0];
    }
    
    if(pointInnerCell.y > 0.5){
        relativePointCoord.y = 1;
        CellIDs[2] = cellIDCorrection(CellIDs[0] + int2(0, 1), int2(uniforms.cellCount));
        pointInnerCellNormalised.y = pointInnerCell.y-0.5;
    }else if(pointInnerCell.y < 0.5){
        relativePointCoord.y = -1;
        CellIDs[2] = cellIDCorrection(CellIDs[0] + int2(0, -1), int2(uniforms.cellCount));
        pointInnerCellNormalised.y = 0.5-pointInnerCell.y;

    }else {
        relativePointCoord = int2(0, 0);
        CellIDs[2] = CellIDs[0];
    }
    CellIDs[3] = cellIDCorrection(CellIDs[0] + relativePointCoord, int2(uniforms.cellCount));
    
    cell.density = (1-pointInnerCellNormalised.x)*(1-pointInnerCellNormalised.y)*cells[idTwo(CellIDs[0])].density + pointInnerCellNormalised.x*(1-pointInnerCellNormalised.y)*cells[idTwo(CellIDs[1])].density + pointInnerCellNormalised.y*(1-pointInnerCellNormalised.x)*cells[idTwo(CellIDs[2])].density + pointInnerCellNormalised.y*pointInnerCellNormalised.x*cells[idTwo(CellIDs[3])].density;
    
    
    Neighboors[0] = cells[id(CellID.x, CellID.y-1)];
    Neighboors[1] = cells[id(CellID.x+1, CellID.y)];
    Neighboors[2] = cells[id(CellID.x, CellID.y+1)];
    Neighboors[3] = cells[id(CellID.x-1, CellID.y)];

    if(CellID.x == 0){
        Neighboors[3] = cells[id(uniforms.cellCount.x-1, CellID.y)];
    }
    if(CellID.x == uniforms.cellCount.x-1){
        Neighboors[1] = cells[id(0, CellID.y)];
    }
    if(CellID.y == 0){
        Neighboors[0] = cells[id(CellID.x, uniforms.cellCount.y-1)];
    }
    if(CellID.y == uniforms.cellCount.y-1){
        Neighboors[2] = cells[id(CellID.x, 0)];
    }
    cell.density = (cell.density+diff*uniforms.deltaTime*(Neighboors[0].density+Neighboors[1].density+Neighboors[2].density+Neighboors[3].density))/(1+4*diff*uniforms.deltaTime);
    
    
    
    
    textureOut.write(half4(cell.density), textureID);
//    textureOut.write(half4(cell.velocityField.x, cell.velocityField.y, 0, 1), textureID);
    uint stateSave = *state;
    uint stateIDSave = *stateID;
    cells[id(CellID.x, CellID.y)] = cell;
    *state = stateSave;
    *stateID = stateIDSave;
    
}
