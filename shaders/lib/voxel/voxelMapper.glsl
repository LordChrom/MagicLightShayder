
#include "/lib/voxel/voxelHelper.glsl"

//block info, RGB are color,
//A is, from MSB to LSB,
// 4 bit emissive strength,
// 2 unused bits
// a bit that's 1 for translucent blocks like stained glass
// a bit that's 1 for surfaces that block light

layout (rgba8ui) uniform writeonly restrict uimage3D worldVox;


void writeVoxelMap(vec3 worldPos, vec3 color, uint emission, bool translucent, bool opaque){
    ivec4 worldPosi = worldPosToSection(worldPos,1);

    if(!isVoxelInBounds(worldPos)) return;

    uint metadata = (emission<<4) + (uint(translucent)<<1) + uint(opaque);
    imageStore(worldVox,worldPosi.xyz,uvec4(255*color,metadata));

}