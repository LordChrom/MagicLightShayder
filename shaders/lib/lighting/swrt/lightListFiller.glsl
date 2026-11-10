#extension GL_KHR_shader_subgroup_shuffle : enable
#include "/lib/settings.glsl"
#define WRITES_LIGHT_LIST
#define READS_LIGHT_LIST
#define READS_BASE_VOX
#include "/lib/voxelStorage/blockPacking.glsl"
#include "/lib/voxelStorage/vsAccess.glsl"
#include "/lib/lighting/swrt/lightListAccess.glsl"
#include "/lib/lighting/swrt/rayIntersect.glsl"


#define WORK_SIZE VOXELSIZE_QUARTER

const ivec3 workGroups = ivec3(WORK_SIZE,1,WORK_SIZE);
layout (local_size_x = 4, local_size_y = SWRT_UPDATE_SPEED, local_size_z = 4) in;

layout(std430, binding = 1) buffer ssbo0 {
    uvec4[64][64] bufferedGroupMeta;
    uint[2][64][64][64] bufferedData;
};

bool personalChanges = false;

ivec3 localPos = ivec3(0);
ivec3 unitShift = ivec3(0);
uint[SWRT_LIGHTS_PER_BLOCK] selfList;
uint[SWRT_LIGHTS_PER_BLOCK] neighborList;
shared uint[gl_WorkGroupSize.x*gl_WorkGroupSize.y*gl_WorkGroupSize.z][SWRT_LIGHTS_PER_BLOCK] outList;
uint itemsInList = 0;

uniform int frameCounter;

uint getVoxel(ivec3 swrtPos){
    return getBaseVoxData(swrtPos,unitShift);
}

uint tagWithLength(uint light){
    light&=LIGHT_NO_META_MASK;
    if(!bool(light&LIGHT_VALID_BIT))
        return 0u;
    float len = packedListedLightLen(light)/maxPossibleLightLen;
    const int LEN_MASK = 0x3ff;
    return light|(uint(clamp(LEN_MASK-int(round(len*LEN_MASK)),0,LEN_MASK))<<22); //so closer lights will be comparable directly with >
}

void verifyLights(){
    uint outIndex = 0u;
    itemsInList = min(itemsInList,SWRT_LIGHTS_PER_BLOCK);
    for(uint i=0;i<itemsInList;i++){
        uint light = outList[gl_LocalInvocationIndex][i]&LIGHT_NO_META_MASK;
        if(!bool(light&LIGHT_VALID_BIT))
            break;
        ivec3 pos = localPos + uncheckedUnpackListedLight(light);
        uint voxel = getVoxel(pos);
        if(!bool(voxel&WORLDVOX_EMISSION_MASK))
            continue;

        //TODO fix fog flickering when this is on
    #if SWRT_PRETRACE_LISTS>=0
        vec3 worldPos = localPos+0.5;
        vec3 lightDir = pos+0.5-worldPos;
        worldPos-=(VOXELIZATION_SIZE>>1)-unitShift;

        #if SWRT_PRETRACE_LISTS>=2

        bool lightReachable = false;

        for(int i=0;i<4;i++){
            vec3 localOffset;
            localOffset.xy=vec2(1-2*ivec2(i>>1,i&1));
            localOffset.z=localOffset.x*localOffset.y;
            localOffset*=0.4;

            float d = traceRay(worldPos+localOffset, lightDir, unitShift, 30u);
            if(d<0){
                lightReachable=true;
                break;
            }
        }
        if(!lightReachable)
            continue;
        #else
        if(traceRay(worldPos, lightDir, unitShift, 30u)>0)
            continue;

        #endif

    #endif

        light |= ((voxel>>WORLDVOX_EMISSION_SHIFT)<<28 ) | (blockLightID(voxel)<<22);
        personalChanges = personalChanges || (light!=selfList[outIndex]);

        outList[gl_LocalInvocationIndex][outIndex] = light;
        outIndex++;
    }
    for(;outIndex<SWRT_LIGHTS_PER_BLOCK;outIndex++){
        outList[gl_LocalInvocationIndex][outIndex] = 0u;
        personalChanges = personalChanges || (selfList[outIndex]!=0u);
    }
}

void storeData(){
    setLightList(outList[gl_LocalInvocationIndex],localPos,unitShift);
}

void merge(ivec3 offset){
    uint neighborIndex = 0;
    uint selfIndex = 0;

    for(;itemsInList<SWRT_LIGHTS_PER_BLOCK && min(selfIndex,neighborIndex)<SWRT_LIGHTS_PER_BLOCK;){
        uint selfLight = tagWithLength(selfList[selfIndex]&LIGHT_NO_META_MASK);
        uint neighborLight = tagWithLength(addToPackedLight(neighborList[neighborIndex],offset)&LIGHT_NO_META_MASK);


        uint preferableLight = (
            (selfLight>neighborLight && selfIndex<SWRT_LIGHTS_PER_BLOCK) || neighborIndex>=SWRT_LIGHTS_PER_BLOCK
        )? selfLight:neighborLight;

        selfIndex    += uint(preferableLight==selfLight     );
        neighborIndex+= uint(preferableLight==neighborLight );

        if(!bool(preferableLight&LIGHT_VALID_BIT))
            break;

        if((itemsInList==0)||preferableLight<outList[gl_LocalInvocationIndex][max(0,int(itemsInList)-1)])
            outList[gl_LocalInvocationIndex][itemsInList++] = preferableLight;
    }
}


shared uvec4 groupMeta;
ivec3 localOffset = ivec3(0,0,0);
void iterateGroupMeta(){
    groupMeta.z+=bool(groupMeta.w)?1:-2;
    if(groupMeta.z>64){
        //TODO some awareness of neighbors' activity
        groupMeta.x++;
        groupMeta.x%=SWRT_SIZE/gl_WorkGroupSize.y;
        groupMeta.z=3u;
    }
    groupMeta.y=(groupMeta.y+1)%6;
}

void main(){
    unitShift=getUnitShift();
    if(gl_LocalInvocationIndex==0u){
        if(frameCounter>0)
            groupMeta = bufferedGroupMeta[gl_WorkGroupID.x][gl_WorkGroupID.z];
        else
            groupMeta=uvec4(0);
        iterateGroupMeta();
        bufferedGroupMeta[gl_WorkGroupID.x][gl_WorkGroupID.z] = uvec4(groupMeta.xyz,0u);
    }

    barrier();


    localPos = ivec3(uvec3(gl_WorkGroupID.x,groupMeta.x,gl_WorkGroupID.z)*gl_WorkGroupSize)
        +ivec3(gl_SubgroupInvocationID%gl_WorkGroupSize.x,
            ((gl_SubgroupInvocationID+gl_SubgroupID*gl_SubgroupSize)/(gl_WorkGroupSize.x*gl_WorkGroupSize.z)),
            (gl_SubgroupInvocationID/gl_WorkGroupSize.x)%gl_WorkGroupSize.z
        );

    uint axis = groupMeta.y>>1;
    localOffset = ivec3(axis==0,axis==1,axis==2)*(1-2*int(groupMeta.y&1u));

    uint voxel = getVoxel(localPos);
    getLightList(selfList,localPos,unitShift);
    getLightList(neighborList,localPos+localOffset,unitShift);


    for(int i=0;i<SWRT_LIGHTS_PER_BLOCK;i++)
        outList[gl_LocalInvocationIndex][i]=0u;

    if(bool(voxel&WORLDVOX_EMISSION_MASK)){
        uint newLight = packListedLight(ivec3(0));
        outList[gl_LocalInvocationIndex][itemsInList++] = tagWithLength(newLight);
    }

    if(!bool(voxel&WORLDVOX_OPAQUE))
        merge(localOffset);

    verifyLights();
    if(personalChanges){
        storeData();
        bufferedGroupMeta[gl_WorkGroupID.x][gl_WorkGroupID.z].w=1;
    }
}

