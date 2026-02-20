
#define WRITES_VOX
#include "/lib/voxel/voxelHelper.glsl"

//block info, RGB are color,
//A is, from MSB to LSB,
// 4 bit emissive strength,
// 2 unused bits
// a bit that's 1 for translucent blocks like stained glass
// a bit that's 1 for surfaces that block light



void writeVoxelMap(vec3 worldPos, vec3 color, uint emission, bool translucent, bool opaque){
    ivec4 worldPosi = worldPosToSection(worldPos,1);

    if(!isVoxelInBounds(worldPos)) return;

    uint metadata = (emission<<4) + (uint(translucent)<<1) + uint(opaque);
    setVoxData(uvec4(255*color,metadata),worldPosi.xyz);

}