#define SAMPLES_LIGHT_FACE
#define WRITES_LIGHT_FACE
#include "/lib/voxel/voxelHelper.glsl"

#if false //dummy definition because intellij's best glsl plugin doesnt know includes exist
struct lightVoxData{vec2 occlusionRay;bvec4 occlusionMap;vec3 color;vec3 lightTravel;float occlusionHitDistance;uint type;uint flags;};
#endif


const ivec3 workGroups = ivec3(1,AREA_SIZE_MEM,12);
layout (local_size_x = AREA_SIZE_MEM, local_size_y = 1, local_size_z = 1) in;

const vec3 sunColor = vec3(242,242,242)/255;
const vec3 sunPos = vec3(0,0,1000);
#ifdef AXES_INORDER
const int workGroupZ = 1;
#else
const int workGroupZ = 6;
#endif


uniform int frameCounter;
//int frameOffset = frameCounter%UPDATE_STRIDE;


layout(std430, binding = 0) restrict buffer areaData {
    areaMeta[AREA_COUNT] areaMeta;
} areaDataAccess;

layout(std430, binding = 1) restrict buffer indirectDispatches {
    uvec3 lighterDispatches;
} indirectDispatchesAccess;

uint zoneMemOffset, axis;
ivec3 zoneOrigin;

void sunlight(ivec3 zonePos){
    vec3 lightTravel = sunPos;
    lightTravel.xy+=zonePos.xy;
    lightVoxData sunLight = {vec2(0,0),bvec4(true),sunColor,lightTravel,0,1,0};
    setLightData(sunLight, ivec3(zonePos), zoneOrigin, zoneMemOffset);
}

void nullify(ivec3 zonePos){
    setLightData(noLight, ivec3(zonePos), zoneOrigin, zoneMemOffset);
}


void fillSeams(uvec3 workGroupID, uvec3 localID){
    indirectDispatchesAccess.lighterDispatches=uvec3(SECTIONS_PER_AREA,NUM_AREAS,workGroupZ);
    uint areaNum = 0;


    uint layer = workGroupID.z%VOX_LAYERS;
    axis = workGroupID.z/VOX_LAYERS;

    ivec3 zonePos = ivec3(ivec2(localID.x,workGroupID.y)-1, -1);

    zoneOrigin = areaToZoneSpace(getAreaOrigin(areaNum),axis);
    zoneMemOffset = zoneOffset(axis,layer);

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


}