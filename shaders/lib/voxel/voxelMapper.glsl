#ifdef OBSTRUCTION_MAPPING
#define WRITES_OBSTRUCTION
#endif

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

    #ifdef OBSTRUCTION_MAPPING
    minWorldPos-=0.1;
    maxWorldPos+=0.1;
    #endif

    ivec3 areaShift = getAreaShift(scale);
    ivec3 areaPos;

    for(areaPos.x=minAreaPos.x;areaPos.x<=maxAreaPos.x;areaPos.x++){
        for(areaPos.y=minAreaPos.y;areaPos.y<=maxAreaPos.y;areaPos.y++){
            for(areaPos.z = minAreaPos.z;areaPos.z<=maxAreaPos.z;areaPos.z++){
                #ifdef OBSTRUCTION_MAPPING
                vec3 lowerCorner = (vec3(areaPos)-(AREA_SIZE*0.5))*scale+getGlobalOrigin(scale);
                vec3 upperCorner = lowerCorner+scale;

                uint obstructedFaces =
                (((minWorldPos.x<=lowerCorner.x && lowerCorner.x<=maxWorldPos.x) ?63u:   0x02u) & //x-
                 ((minWorldPos.x<=upperCorner.x && upperCorner.x<=maxWorldPos.x) ?63u:   0x01u))& //x+
                (((minWorldPos.y<=lowerCorner.y && lowerCorner.y<=maxWorldPos.y) ?63u:   0x08u) & //y-
                 ((minWorldPos.y<=upperCorner.y && upperCorner.y<=maxWorldPos.y) ?63u:   0x04u))& //y+
                (((minWorldPos.z<=lowerCorner.z && lowerCorner.z<=maxWorldPos.z) ?63u:   0x20u) & //z-
                 ((minWorldPos.z<=upperCorner.z && upperCorner.z<=maxWorldPos.z) ?63u:   0x10u)); //z+


                if(bool(obstructedFaces)){
                    submitObstructionData(obstructedFaces, areaPos, areaShift, areaMemOffset);
                    if(bitCount(obstructedFaces)==1 && !bool(emission)){
                        uint secondaryObstruction = ((obstructedFaces&0x15u)<<1)|((obstructedFaces&0x2au)>>1);
                        ivec3 secondaryAreaPos = areaPos+(bool(secondaryObstruction&0x15u)?1:-1)*ivec3(bvec3(secondaryObstruction&3u,secondaryObstruction&12u,secondaryObstruction&48u));
                        submitObstructionData(secondaryObstruction, secondaryAreaPos, areaShift, areaMemOffset);
                    }
                }
                #endif
                updateVoxData(packedData, areaPos, areaShift, areaMemOffset);
            }
        }
    }
}