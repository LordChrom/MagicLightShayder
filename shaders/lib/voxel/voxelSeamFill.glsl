
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
struct lightVoxData{vec2 occlusionRay;bvec4 occlusionMap;vec3 color;uint type;vec3 lightTravel;float columnation;};
#endif

const vec3 sunColor = normalize(vec3(0.61,0.61,0.6))*SUNLIGHT_STRENGTH;

vec3 sunPos = vec3(0,0,1000);

void sunlight(uvec3 texelPos){
    vec3 lightTravel = sunPos;
    lightTravel.xy+=texelPos.xy;
    lightVoxData sunLight = {vec2(0,0),bvec4(true),sunColor,lightTravel,1,1};
    setLightData(sunLight, ivec3(texelPos));

}

void nullify(uvec3 texelPos){
    setLightData(noLight, ivec3(texelPos));
}


void fillSeams(uvec3 workGroupID, uvec3 localID){
    uint zoneNum = 0;

    uint layer = workGroupID.z%VOX_LAYERS;
    uint axis = workGroupID.z/VOX_LAYERS;


//    ivec4 sectionPos = ivec4(0,AREA_SIZE,0,zoneNum);
//    sectionPos.xz = ivec2(localID.xy + (workGroupID.xy*SECTION_SIZE));
//    uvec3 texelPos = areaToZoneSpace(sectionPos,axis,layer).xyz;
    uvec3 texelPos;
    //    texelPos.xy = ivec2(localID.xy + (workGroupID.xy*SECTION_SIZE));
    texelPos.xy = ivec2(localID.x,workGroupID.y);

    texelPos.z = zoneOffset(axis,layer);

    if(axis==2)
        sunlight(texelPos);
    else
        nullify(texelPos);


}