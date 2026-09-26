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
uint[SWRT_LIGHTS_PER_BLOCK] selfList;
uint[SWRT_LIGHTS_PER_BLOCK] neighborList;
uint[SWRT_LIGHTS_PER_BLOCK] outList;
uint itemsInList = 0;

void zeroPosition(ivec3 pos, bool isTop){
    clearLightList(pos, unitShift);
}
#define MOVEMENT_TRIM
#include "/lib/util/3dComputeShaderUtils.glsl"

uint getVoxel(ivec3 swrtPos){
    return getBaseVoxData(swrtPos,unitShift);
}

uint tagWithLength(uint light){
    light&=0xffffu;
    if(!bool(light&LIGHT_VALID_BIT))
        return 0u;
    float len = packedListedLightLen(light)/maxPossibleLightLen;
    return light|(uint(clamp(0xffff-int(round(len*0xffff)),0,0xffff))<<16); //so closer lights will be comparable directly with >
}

void verifyLights(){
    uint outIndex = 0u;
    itemsInList = min(itemsInList,SWRT_LIGHTS_PER_BLOCK);
    for(uint i=0;i<itemsInList;i++){
        uint light = outList[i]&0xffffu;
        if(!bool(light&LIGHT_VALID_BIT))
            break;
        ivec3 pos = localPos + uncheckedUnpackListedLight(light);
        uint voxel = getVoxel(pos);
        if(!bool(voxel&WORLDVOX_EMISSION_MASK))
            continue;
        //TODO trace??

        light |= ((voxel>>WORLDVOX_EMISSION_SHIFT)<<28 ) | (blockLightID(voxel)<<16);
        outList[outIndex] = light;
        outIndex++;
    }
    for(;outIndex<SWRT_LIGHTS_PER_BLOCK;outIndex++)
        outList[outIndex] = 0u;
}

void storeData(){
    setLightList(outList,localPos,unitShift);
}

void merge(ivec3 offset){
    uint neighborIndex = 0;
    uint selfIndex = 0;

    for(;itemsInList<SWRT_LIGHTS_PER_BLOCK && min(selfIndex,neighborIndex)<SWRT_LIGHTS_PER_BLOCK;){
        uint selfLight = tagWithLength(selfList[selfIndex]&0xffffu);
        uint neighborLight = tagWithLength(addToPackedLight(neighborList[neighborIndex],offset)&0xffffu);


        uint preferableLight = (
            (selfLight>neighborLight && selfIndex<SWRT_LIGHTS_PER_BLOCK) || neighborIndex>=SWRT_LIGHTS_PER_BLOCK
        )? selfLight:neighborLight;

        selfIndex    += uint(preferableLight==selfLight     );
        neighborIndex+= uint(preferableLight==neighborLight );

        if(!bool(preferableLight&LIGHT_VALID_BIT))
            break;

        if((itemsInList==0)||preferableLight<outList[max(0,int(itemsInList)-1)])
            outList[itemsInList++] = preferableLight;
    }
}

void main(){
    unitShift=getUnitShift();
    localPos = ivec3(gl_LocalInvocationID+gl_WorkGroupID*SIZE);
    ivec3 previousUnitShift = getPreviousUnitShift();

    //TODO make this work with the more parralel ver
    movementTrimParallel(SWRT_SIZE, unitShift, previousUnitShift);

    //TODO probably would benefit from shared mem
    #define DISTANCE_BASED_LIGHT_LIST_SPEED
    #ifdef DISTANCE_BASED_LIGHT_LIST_SPEED
    uint updatePeriod = getUpdatePeriod();

    #ifdef JUMPSTART_LIGHTING
    if(frameCounter<54) updatePeriod=1u;
    #endif

    bool shouldCompute = shouldCompute(updatePeriod);
    if(!shouldCompute)
        return;
    #else
        const uint updatePeriod = 1u;
    #endif

    int frame = int(uint(frameCounter)/updatePeriod);
    ivec3 localOffset = ((ivec3(frame/3,frame/9+frame,frame))%3)-1;

    uint voxel = getVoxel(localPos);
    getLightList(selfList,localPos,unitShift);
    getLightList(neighborList,localPos+localOffset,unitShift);


    for(int i=0;i<SWRT_LIGHTS_PER_BLOCK;i++)
        outList[i]=0u;

    if(bool(voxel&WORLDVOX_EMISSION_MASK)){
        uint newLight = packListedLight(ivec3(0));
        outList[itemsInList++] = tagWithLength(newLight);
    }

    if(!bool(voxel&WORLDVOX_OPAQUE))
        merge(localOffset);

    verifyLights();
    storeData();
}

