#define WRITES_VOX
#include "/lib/lighting/floodShadows/voxelHelper.glsl"
#include "/lib/voxelStorage/blockPacking.glsl"

const float midblockWeight = MIN_SCALE* 12.0/16.0;
const float normalWeight = -MIN_SCALE*3.0/64.0;

void writeVoxelMap(vec3 worldPos, int rawBlockID, vec3 toMidblock, vec3 normal, uint emission){
//    if(max(max(abs(toMidblock.x),abs(toMidblock.y)),abs(toMidblock.z))>0.5)
//        return; //for blocks that dont fit in the box, altho not best solution

    uint packedData = packVoxelForStorage(rawBlockID,emission);



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
    uint packedData = packVoxelForStorage(rawBlockID,emission);

    const float inset = 1.0/16.0;

    vec3 centerWorldPos = 0.5*(minWorldPos+maxWorldPos)-0.01*normal;

    uint cascadeLevel = getCascadeLevel(centerWorldPos);
    uint areaMemOffset = areaOffset(cascadeLevel);
    float scale = getScale(cascadeLevel);

    ivec3 minAreaPos = worldPosToArea(min(minWorldPos+inset,centerWorldPos),scale);
    ivec3 maxAreaPos = worldPosToArea(max(maxWorldPos-inset,centerWorldPos),scale);


    if((maxAreaPos.x-minAreaPos.x)*(maxAreaPos.y-minAreaPos.y)*(maxAreaPos.z-minAreaPos.z)>16)
    return;

    ivec3 areaShift = getAreaShift(scale);
    ivec3 areaPos;

    for(areaPos.x=minAreaPos.x;areaPos.x<=maxAreaPos.x;areaPos.x++){
        for(areaPos.y=minAreaPos.y;areaPos.y<=maxAreaPos.y;areaPos.y++){
            for(areaPos.z = minAreaPos.z;areaPos.z<=maxAreaPos.z;areaPos.z++){
                updateVoxData(packedData, areaPos, areaShift, areaMemOffset);
            }
        }
    }
}