#include "/lib/settings.glsl"
#define WRITES_LIGHT_LIST
#define READS_LIGHT_LIST
#define READS_BASE_VOX
#include "/lib/voxelStorage/blockPacking.glsl"
#include "/lib/voxelStorage/vsAccess.glsl"
#include "/lib/lighting/swrt/lightListAccess.glsl"


#define SIZE 8

#if SIZE==8
    #define WORK_SIZE VOXELSIZE_EIGTH
#else
    #define SIZE 16
    #define WORK_SIZE VOXELSIZE_SIXTNTH
#endif

const ivec3 workGroups = ivec3(WORK_SIZE,WORK_SIZE,WORK_SIZE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = SIZE) in;

ivec3 localPos, unitShift;
uint[8] personalList, personalListCopy;

void zeroPosition(ivec3 pos, bool isTop){
    setLightList(uvec4(0), pos, unitShift);
}
#define MOVEMENT_TRIM
#include "/lib/util/3dComputeShaderUtils.glsl"

uint getVoxel(ivec3 swrtPos){
    return getBaseVoxData(swrtPos,unitShift);
}

void tagWithLength(inout uint light){
    light&=0xffffu;
    if(!bool(light&LIGHT_VALID_BIT)){
        light=0u;
        return;
    }
    float len = packedListedLightLen(light)/maxPossibleLightLen;
    light|=uint(clamp(int((1-len)*0xffff),0,0xffff))<<16; //so closer lights will be comparable directly with >
}

void removeNonexistentLights(){
    uint testIndex = 0;
    for(uint i=0;i<8;i++){
        uint light = personalList[i];
        bool validLight = bool(light&LIGHT_VALID_BIT);
        if(validLight){
            ivec3 pos = localPos + uncheckedUnpackListedLight(light);
            validLight = bool(getVoxel(pos)&WORLDVOX_EMISSION_MASK);
            //TODO trace??
        }
        
        if(!validLight)
            personalList[i] = 0u;
    }
}

uvec4 packList(){
    uvec4 ret;
    for(uint i=0;i<4;i++){
        uint listIndex = i+i;
        ret[i] = (personalList[listIndex]&0xffffu)|(personalList[listIndex+1]<<16);
    }
    return ret;
}

void merge(uvec4 neighbor, ivec3 offset){

    uint neighborIndex = 0;
    uint selfIndex = 0;

    for(uint i=0;i<8;i++){
        personalListCopy[i]=personalList[i];
    }

    for(int i=0;i<8 && min(selfIndex,neighborIndex)<8 ;i++){
        uint neighborLight = getNthLight(neighbor,neighborIndex);
        uint selfLight = personalListCopy[i];

        neighborLight=addToPackedLight(neighborLight,offset);
        tagWithLength(neighborLight);
        bool selfPreferable = (selfLight>neighborLight && selfIndex<8) || neighborIndex>=8;

        uint preferableLight;
        if(selfPreferable){
            selfIndex++;
            preferableLight = selfLight;
        }else{
            neighborIndex++;
            preferableLight = neighborLight;
        }

        if(i>0)
            if(preferableLight>=personalList[i-1]){
                i--;
                continue;
            }
        personalList[i] = selfPreferable?selfLight:neighborLight;
    }
}

void mergeFromOffset(ivec3 offset){
    uvec4 neighborList = getLightList(localPos+offset,unitShift);
    merge(neighborList,offset);
}

void main(){
    unitShift=getUnitShift();
    ivec3 previousUnitShift = getPreviousUnitShift();

    //TODO make this work with the more parralel ver
//    movementTrim(SWRT_SIZE, unitShift, previousUnitShift);

    //TODO probably would benefit from shared mem
    #define DISTANCE_BASED_LIGHT_LIST_SPEED
    #ifdef DISTANCE_BASED_LIGHT_LIST_SPEED
    bool shouldCompute = shouldCompute(getUpdatePeriod());
    #ifdef JUMPSTART_LIGHTING
    shouldCompute=shouldCompute||frameCounter<20;
    #endif
    if(!shouldCompute)
        return;
    #endif

    localPos = ivec3(gl_LocalInvocationID+gl_WorkGroupID*SIZE);

    uint voxel = getVoxel(localPos);

    for(int i=0;i<8;i++){
        personalList[i]=0u;
    }

    if(bool(voxel&WORLDVOX_EMISSION_MASK)){
        uint light = packListedLight(ivec3(0));
        tagWithLength(light);
        personalList[0]=light;
    }


    mergeFromOffset(ivec3(0));

    ivec3 localOffset;
    if(!bool(voxel&WORLDVOX_OPAQUE)){
        localOffset = ((ivec3(frameCounter)/ivec3(9,3,1))%3)-1;
        if(localOffset==ivec3(0))
            return;
        mergeFromOffset(localOffset);
    }
    removeNonexistentLights();
    setLightList(packList(),localPos,unitShift);
}

