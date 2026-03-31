#define SAMPLES_LIGHT_FACE
#define WRITES_LIGHT_FACE
#include "/lib/voxel/voxelHelper.glsl"

#if false //dummy definition because intellij's best glsl plugin doesnt know includes exist
struct lightVoxData{vec2 occlusionRay;bvec4 occlusionMap;vec3 color;vec3 lightTravel;float occlusionHitDistance;uint type;uint flags;};
#endif


//TODO variable for layers
const ivec3 workGroups = ivec3(2,AREA_SIZE_MEM,12);
layout (local_size_x = AREA_SIZE_MEM, local_size_y = 1, local_size_z = 1) in;

const vec3 sunColor = vec3(242,242,242)/255;
const vec3 sunPos = vec3(0,0,1000);
#ifdef AXES_INORDER
const int workGroupZ = 2;
#else
const int workGroupZ = 6*2;
#endif


uniform int frameCounter;
//int frameOffset = frameCounter%UPDATE_STRIDE;


layout(std430, binding = 0) restrict buffer areaData {
    areaMeta[AREA_COUNT] areaMeta;
} areaDataAccess;

layout(std430, binding = 1) restrict buffer indirectDispatches {
    uvec3 lighterDispatches;
} indirectDispatchesAccess;

float scale;
uint zoneMemOffset, axis;
ivec3 zoneShift;

void sunlight(ivec3 zonePos){
    vec3 lightTravel = sunPos;
    lightTravel.xy+=zonePos.xy;
    lightVoxData sunLight = {vec2(0,0),bvec4(true),sunColor,lightTravel,0,1,0};
    setLightData(sunLight, ivec3(zonePos), zoneShift, zoneMemOffset);
}

void nullify(ivec3 zonePos){
    setLightData(noLight, ivec3(zonePos), zoneShift, zoneMemOffset);
}

void trim(ivec3 zonePos){
    nullify(zonePos); //TODO sample from lower detail region
}

void fillSeams(uvec3 workGroupID, uvec3 localID){
    indirectDispatchesAccess.lighterDispatches=uvec3(SECTIONS_PER_AREA,NUM_AREAS,workGroupZ);
//    uint cascadeLevel = workGroupID.x;
    uint cascadeLevel=0;
    if((workGroupID .z&1u)!=0){
        cascadeLevel=1+countTrailingZeroes(frameCounter);
    }
    if(cascadeLevel>=NUM_CASCADES) return;

    uint layer = workGroupID.z%VOX_LAYERS;
    axis = workGroupID.z/VOX_LAYERS;

    ivec3 zonePos = ivec3(ivec2(localID.x,workGroupID.y)-1, -1);
    scale = getScale(cascadeLevel);
    ivec3 areaShift = getAreaShift(scale);

    zoneShift = areaToZoneSpace(areaShift,axis);
    zoneMemOffset = zoneOffset(axis,layer,cascadeLevel);
    ivec3 zoneMovement = areaToZoneSpaceRelative(areaShift - getPreviousAreaShift(scale),axis);

    if(localID==ivec3(0)){

    }

    if(axis==2){
//        if (layer==0)
//            sunlight(zonePos);
//        else
            nullify(zonePos);
    }else{
        //        nullify(texelPos);
    }


    ivec3 movementSigns = sign(zoneMovement);
    ivec3 edgeToTrim = abs(zoneMovement);

    for(int i=0; i<edgeToTrim.z;i++){
        int L = movementSigns.z>0?63-i:i;
        trim(ivec3(zonePos.xy,L));
    }

    for(int i=0; i<edgeToTrim.x;i++){
        int A = movementSigns.x>0?63-i:i;
        trim(ivec3(A,zonePos.xy));
    }

    for(int i=0; i<edgeToTrim.y;i++){
        int B = movementSigns.y>0?63-i:i;
        trim(ivec3(zonePos.x,B,zonePos.y));
    }

}