
#include "/lib/voxel/voxelHelper.glsl"

//block info, RGB are color,
//A is, from MSB to LSB,
// 4 bit emissive strength,
// 2 unused bits
// a bit that's 1 for translucent blocks like stained glass
// a bit that's 1 for surfaces that block light

layout (rgba8ui) uniform writeonly restrict uimage3D worldVox;


void writeVoxelMap(vec3 worldPos, uvec4 blockInfo){

    worldPos=worldPos*1-vec3(0.01);
    ivec3 worldPosi = ivec3(round(worldPos));

    if(!isVoxelInBounds(worldPos)) return;

    imageStore(worldVox,worldPosi,uvec4(100,1,0,blockInfo.a));

}