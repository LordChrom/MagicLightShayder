
#define WRITES_VOX
#include "/lib/voxel/voxelHelper.glsl"



void writeVoxelMap(vec3 worldPos, int blockID, vec3 toMidblock, vec3 normal, uint emission){
//    if(max(max(abs(toMidblock.x),abs(toMidblock.y)),abs(toMidblock.z))>0.5)
//        return; //for blocks that dont fit in the box, altho not best solution

    vec3 color = vec3(0.9,0.6,0.6);
    uint metadata;

    if(blockID>=0){
        color.r=(blockID/100)%10;
        color.g=(blockID/10)%10;
        color.b=(blockID)%10;
        color/=9;


        metadata = ((blockID/1000u)%10u)&3u;
        if(emission>0){
            color*=float(emission)*0.06666; //1/15
            metadata&=0xfeu;
            metadata |= ((blockID/10000u)%10u)<<(VOXEL_TYPE_SHIFT-WORLDVOX_SHIFT);
        }

    }else{
        color=vec3(1,0,0);
        metadata=1;
    }

    const float midblockWeight = MIN_SCALE* 15.0/16.0;
    const float normalWeight = -MIN_SCALE*3.0/64.0;

    worldPos += midblockWeight*toMidblock -0.015625*normal;

    uint cascadeLevel = getCascadeLevel(worldPos);

    float scale = getScale(cascadeLevel);
    vec3 svo = subVoxelOffset(worldPos,scale);
    if(abs(svo.x*svo.y*svo.z) <= 1e-6)
        return;
    ivec3 areaPos = worldPosToArea(worldPos, scale);
    ivec3 areaShift = getAreaShift(scale);
    uint areaMemOffset = areaOffset(cascadeLevel);

//TODO Comedian: What's the deal with end rods? *laugh track*

    uint packedData = packWorldVox(uvec4(255*color, metadata)) | (VOXEL_INITIAL_TIME<<VOXEL_AGE_SHIFT);
    updateVoxData(packedData, areaPos, areaShift, areaMemOffset);
}