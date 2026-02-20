
#define WRITES_VOX
#include "/lib/voxel/voxelHelper.glsl"

//block info, RGB are color,
//A is, from MSB to LSB,
// 4 bit emissive strength,
// 2 unused bits
// a bit that's 1 for translucent blocks like stained glass
// a bit that's 1 for surfaces that block light



void writeVoxelMap(vec3 worldPos, int blockID, uint emission, bool translucent, bool opaque){
    vec3 color = vec3(0.9,0.6,0.6);
    if(blockID>=0){
        color.r=(blockID/100)%10;
        color.g=(blockID/10)%10;
        color.b=(blockID)%10;
        color/=8;
    }else{
//        color=vec3(1,0.95,0.85);
        color=vec3(1,0,0);

    }
//    color=normalize(color);
    ivec4 worldPosi = worldPosToSection(worldPos,1);

    if(!isVoxelInBounds(worldPos)) return;

    uint metadata = (emission<<4) + (uint(translucent)<<1) + uint(opaque);
    setVoxData(uvec4(255*color,metadata),worldPosi.xyz);
}