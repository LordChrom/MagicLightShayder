#define SAMPLES_LIGHT_FACE
#define WRITES_LIGHT_FACE
#include "/lib/voxel/voxelHelper.glsl"

uniform int heightLimit;

#if false //dummy definition because intellij's best glsl plugin doesnt know includes exist
struct lightVoxData{vec2 occlusionRay;bvec4 occlusionMap;vec3 color;vec3 lightTravel;float occlusionHitDistance;uint type;uint flags;};
#endif


//one for each axis * layer combo, and also one for the world
#if VOX_LAYERS==1
    #define AXIS_LAYER_WORLD_COUNT 7
#elif VOX_LAYERS==2
    #define AXIS_LAYER_WORLD_COUNT 13
#elif VOX_LAYERS==3
    #define AXIS_LAYER_WORLD_COUNT 19
#elif VOX_LAYERS==4
    #define AXIS_LAYER_WORLD_COUNT 25
#elif VOX_LAYERS==5
    #define AXIS_LAYER_WORLD_COUNT 31
#elif VOX_LAYERS==6
    #define AXIS_LAYER_WORLD_COUNT 37
#elif VOX_LAYERS==7
    #define AXIS_LAYER_WORLD_COUNT 43
#elif VOX_LAYERS==8
    #define AXIS_LAYER_WORLD_COUNT 49
#endif

const ivec3 workGroups = ivec3(PROC_MULT,AREA_SIZE_MEM,AXIS_LAYER_WORLD_COUNT);
layout (local_size_x = AREA_SIZE_MEM, local_size_y = 1, local_size_z = 1) in;

const vec3 sunColor = vec3(242,242,242)/255;
const vec3 sunPos = vec3(0,0,1000);
const lightVoxData defaultSunLight = {vec2(0,0),bvec4(true),sunColor,ivec3(0,0,10),0,1,0};

const int workGroupZ = 6*PROC_MULT;



layout(std430, binding = 0) restrict buffer areaData {
    areaMeta[AREA_COUNT] areaMeta;
} areaDataAccess;

layout(std430, binding = 1) restrict buffer indirectDispatches {
    uvec3 lighterDispatches;
} indirectDispatchesAccess;

float scale;
uint zoneMemOffset, upZoneMemOffset, axis, cascadeLevel;
ivec3 zoneShift, upZoneShift;


void nullify(ivec3 zonePos){
    setLightData(noLight, ivec3(zonePos), zoneShift, zoneMemOffset);
}

void trim(ivec3 zonePos){
    lightVoxData light = noLight;

    ivec3 upZonePos = (zonePos+(AREA_SIZE/2))/2;
    vec3 zonePosRemnants = (vec3(zonePos&1)-0.5)*scale;
    //TODO check if position in higher volume hasnt been shifted out of bounds, but should only be an issue when moving *very* fast
    bool upsampleValid = bool(upZoneMemOffset);
    if(upsampleValid){
        uvec4 packedUpsample = sampleLightData(upZonePos,upZoneShift,upZoneMemOffset);
        lightVoxData outerLight =  unpackLightData(packedUpsample); //TODO operate only on the light travel
        if(outerLight.type!=LIGHT_TYPE_SUN)
            outerLight.lightTravel+=zonePosRemnants;
        light=outerLight;
    }
    if(axis==2 && zonePos.z==-1){
        float height = getGlobalOrigin(scale).y+0.5*scale*AREA_SIZE;
        if(height>=heightLimit || (cascadeLevel==(NUM_CASCADES-1)))
            light = defaultSunLight;
    }
    setLightData(light, ivec3(zonePos), zoneShift, zoneMemOffset);
}

void fillLightSeams(uvec3 workGroupID, uvec3 localID){
    indirectDispatchesAccess.lighterDispatches=uvec3(SECTIONS_PER_AREA_XY,SECTIONS_PER_AREA_Z,workGroupZ);

    int frameBasedOffset = frameCounter;
    cascadeLevel = getVariableCascadeLevel(frameBasedOffset,bool(workGroupID.x&1u));
    if(cascadeLevel>=NUM_CASCADES) return;

    #ifdef DOUBLE_PROC
    frameBasedOffset=(frameBasedOffset>>cascadeLevel);
    #else
    frameBasedOffset=(frameBasedOffset>>(cascadeLevel+1));
    #endif

    uint layer = workGroupID.z%VOX_LAYERS;
    axis = workGroupID.z/VOX_LAYERS;

    ivec3 zonePos = ivec3(ivec2(localID.x,workGroupID.y)-1, -1);
    scale = getScale(cascadeLevel);
    ivec3 areaShift = getAreaShift(scale);
    zoneShift = areaToZoneSpace(areaShift,axis);
    ivec3 zoneMovement = areaToZoneSpaceRelative(areaShift - getPreviousAreaShift(scale),axis);

    zoneMemOffset = zoneOffset(axis,layer,cascadeLevel);
    upZoneMemOffset = (cascadeLevel<NUM_CASCADES-1)?zoneOffset(axis,layer,cascadeLevel+1) : 0;
    upZoneShift = areaToZoneSpace(getAreaShift(scale*2),axis);

    trim(ivec3(zonePos.xy,-1));
    trim(ivec3(AREA_SIZE+1,zonePos.xy));
    trim(ivec3(         -1,zonePos.xy));
    trim(ivec3(zonePos.x,AREA_SIZE+1,zonePos.y));
    trim(ivec3(zonePos.x,         -1,zonePos.y));
    //TODO make only do the recetnly updated ones
    //TODO make do inward light

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

void fillVoxSeams(uvec3 workGroupID, uvec3 localID){
    ivec3 areaPos = ivec3(ivec2(localID.x,workGroupID.y)-1, -1);

}

void fillSeams(uvec3 workGroupID, uvec3 localID){
    if(localID.z==(AXIS_LAYER_WORLD_COUNT-1))
        fillVoxSeams(workGroupID, localID);
    else
        fillLightSeams(workGroupID,localID);

}