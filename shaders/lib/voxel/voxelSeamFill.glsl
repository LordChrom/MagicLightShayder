
#define SAMPLES_LIGHT_FACE
#define WRITES_LIGHT_FACE
//#define SAMPLES_VOX
#include "/lib/voxel/voxelHelper.glsl"


uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_STRIDE;

//const ivec3 workGroups = ivec3(groupCountXY,groupCountXY,groupCountZ);
const ivec3 workGroups = ivec3(1,AREA_SIZE_MEM,12);
//const ivec3 workGroups = ivec3(1,1,6);
layout (local_size_x = AREA_SIZE_MEM, local_size_y = 1, local_size_z = 1) in;

#if false //dummy definition because intellij's best glsl plugin doesnt know includes exist
struct lightVoxData{vec2 occlusionRay;bvec4 occlusionMap;vec3 color;vec3 lightTravel;float occlusionHitDistance;uint type;uint flags;};
#endif

const vec3 sunColor = vec3(242,242,242)/255;

const vec3 sunPos = vec3(0,0,1000);
uint zoneMemOffset;

void sunlight(ivec3 zonePos){
    vec3 lightTravel = sunPos;
    lightTravel.xy+=zonePos.xy;
    lightVoxData sunLight = {vec2(0,0),bvec4(true),sunColor,lightTravel,0,1,0};
    setLightData(sunLight, ivec3(zonePos), zoneMemOffset);
}

void nullify(ivec3 zonePos){
    setLightData(noLight, ivec3(zonePos), zoneMemOffset);
}


void fillSeams(uvec3 workGroupID, uvec3 localID){
    uint zoneNum = 0;

    uint layer = workGroupID.z%VOX_LAYERS;
    uint axis = workGroupID.z/VOX_LAYERS;

    ivec3 zonePos = ivec3(ivec2(localID.x,workGroupID.y)-1, -1);

    zoneMemOffset = zoneOffset(axis,layer);

    if(axis==2){
        if (layer==0)
            sunlight(zonePos);
    }else{
        //        nullify(texelPos);
    }


}