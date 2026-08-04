
#define WRITES_VOX
#include "/lib/voxel/voxelHelper.glsl"

uint voxelInfo(int rawBlockID, uint emission){
    vec3 color = vec3(0.9,0.6,0.6);
    uint metadata;

    if(rawBlockID>=0){
        uint blockID = uint(rawBlockID);
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
    return packWorldVox(uvec4(255*color, metadata)) | uint(VOXEL_INITIAL_TIME<<VOXEL_AGE_SHIFT);
}

const float midblockWeight = MIN_SCALE* 12.0/16.0;
const float normalWeight = -MIN_SCALE*3.0/64.0;

void writeVoxelMap(vec3 worldPos, int rawBlockID, vec3 toMidblock, vec3 normal, uint emission){
//    if(max(max(abs(toMidblock.x),abs(toMidblock.y)),abs(toMidblock.z))>0.5)
//        return; //for blocks that dont fit in the box, altho not best solution

    uint packedData = voxelInfo(rawBlockID,emission);



    worldPos += midblockWeight*toMidblock +normalWeight*normal;

    uint cascadeLevel = getCascadeLevel(worldPos);

    float scale = getScale(cascadeLevel);
    vec3 svo = subVoxelOffset(worldPos,scale);
    if(abs(svo.x*svo.y*svo.z) <= 1e-6)
        return;
    ivec3 areaPos = worldPosToArea(worldPos, scale);
    ivec3 areaShift = getAreaShift(scale);
    uint areaMemOffset = areaOffset(cascadeLevel);


    updateVoxData(packedData, areaPos, areaShift, areaMemOffset);
}

void writeVoxelMap(vec3 minWorldPos, vec3 maxWorldPos, int rawBlockID, vec3 normal, uint emission){
    uint packedData = voxelInfo(rawBlockID,emission);

    const float inset = 1.0/16.0;

    vec3 centerWorldPos = 0.5*(minWorldPos+maxWorldPos)-0.01*normal;

    uint cascadeLevel = getCascadeLevel(centerWorldPos);
    uint areaMemOffset = areaOffset(cascadeLevel);
    float scale = getScale(cascadeLevel);

    ivec3 minAreaPos = worldPosToArea(min(minWorldPos+inset,centerWorldPos),scale);
    ivec3 maxAreaPos = worldPosToArea(max(maxWorldPos-inset,centerWorldPos),scale);


    ivec3 areaShift = getAreaShift(scale);
    for(int x=minAreaPos.x;x<=maxAreaPos.x;x++){
        for(int y=minAreaPos.y;y<=maxAreaPos.y;y++){
            for(int zz = minAreaPos.z;zz<=maxAreaPos.z;zz++){
                updateVoxData(packedData, ivec3(x,y,zz), areaShift, areaMemOffset);
            }
        }
    }
}