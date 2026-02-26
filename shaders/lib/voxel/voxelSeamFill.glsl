
#define SAMPLES_LIGHT_FACE
#define WRITES_LIGHT_FACE
//#define SAMPLES_VOX
#include "/lib/voxel/voxelHelper.glsl"


uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_STRIDE;

//const ivec3 workGroups = ivec3(groupCountXY,groupCountXY,groupCountZ);
const ivec3 workGroups = ivec3(AREA_WIDTH_SECTIONS,AREA_WIDTH_SECTIONS,1);
//const ivec3 workGroups = ivec3(1,1,6);
layout (local_size_x = SECTION_SIZE, local_size_y = SECTION_SIZE, local_size_z = 1) in;

#if false //dummy definition because intellij's best glsl plugin doesnt know includes exist
struct lightVoxData{vec2 occlusionRay;bvec4 occlusionMap;vec3 color;uint emission;vec3 lightTravel;float columnation;};
#endif

const vec3 sunColor = normalize(vec3(0.61,0.61,0.6))*1.3;

vec3 sunPos = vec3(0,0,1000);

void sunlight(uvec3 texelPos){
    vec3 lightTravel = sunPos;
    lightTravel.xy+=texelPos.xy;
    lightVoxData sunLight = {vec2(0,0),bvec4(true),sunColor,15,lightTravel,1};
    setLightData(sunLight, ivec3(texelPos));

}

void fillSeams(uvec3 workGroupID, uvec3 localID){
    uint zoneNum = 0;

    int layer = 1;
    uint axis = 2;

    ivec4 sectionPos = ivec4(0,AREA_SIZE,0,zoneNum);
    sectionPos.xz = ivec2(localID.xy + (workGroupID.xy*SECTION_SIZE));
    uvec3 texelPos = areaToZoneSpace(sectionPos,axis,layer).xyz;
    sunlight(texelPos);


}