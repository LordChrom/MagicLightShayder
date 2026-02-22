
#define READS_LIGHT_FACE
#define WRITES_LIGHT_FACE
//#define READS_VOX
#include "/lib/voxel/voxelHelper.glsl"


uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_STRIDE;

//const ivec3 workGroups = ivec3(groupCountXY,groupCountXY,groupCountZ);
const ivec3 workGroups = ivec3(ZONE_WIDTH_SECTIONS,ZONE_WIDTH_SECTIONS,1);
//const ivec3 workGroups = ivec3(1,1,6);
layout (local_size_x = SECTION_SIZE, local_size_y = SECTION_SIZE, local_size_z = 1) in;

#if false //dummy definition because intellij's best glsl plugin doesnt know includes exist
struct lightVoxData{vec2 occlusionRay;bvec4 occlusionMap;vec3 color;uint emission;vec3 lightTravel;};
#endif

void sunlight(uvec3 texelPos){

    //    uint zoneNum = workGroupID.x;
    lightVoxData sunLight = {vec2(0,0),bvec4(true),vec3(1,1,1),15,vec3(0)};
    setLightData(sunLight, ivec3(texelPos));

}

void fillSeams(uvec3 workGroupID, uvec3 localID){
    uint zoneNum = 0;
    int layerCount = VOX_LAYERS;
    for(int layer = 0; layer<layerCount;layer++){
        uvec3 texelPos;
        uint axis = 2;
        texelPos.xy = localID.xy + 1 + SECTION_SIZE*workGroupID.xy;
        texelPos.z=0;
        texelPos.z+=int((ZONE_SIZE+10)*(VOX_LAYERS*axis+layer)); //TODO fix overlap better
        sunlight(texelPos);
    }

}