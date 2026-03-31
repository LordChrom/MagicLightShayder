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



layout(std430, binding = 0) restrict buffer areaData {
    areaMeta[AREA_COUNT] areaMeta;
} areaDataAccess;

layout(std430, binding = 1) restrict buffer indirectDispatches {
    uvec3 lighterDispatches;
} indirectDispatchesAccess;

float scale;
uint zoneMemOffset, upZoneMemOffset, axis;
ivec3 zoneShift, upZoneShift;

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
    lightVoxData light = noLight;

    ivec3 upZonePos = (zonePos+(AREA_SIZE/2))/2;
    vec3 zonePosRemnants = (vec3(zonePos&1)-0.5)*scale;
    //TODO check if position in higher volume hasnt been shifted out of bounds, but should only be an issue when moving *very* fast
    bool upsampleValid = bool(upZoneMemOffset);
    if(upsampleValid){
        uvec4 packedUpsample = sampleLightData(upZonePos,upZoneShift,upZoneMemOffset);
        lightVoxData outerLight =  unpackLightData(packedUpsample); //TODO operate only on the light travel
        outerLight.lightTravel+=zonePosRemnants;
        light=outerLight;
    }
    setLightData(light, ivec3(zonePos), zoneShift, zoneMemOffset);
}

void fillSeams(uvec3 workGroupID, uvec3 localID){
    indirectDispatchesAccess.lighterDispatches=uvec3(SECTIONS_PER_AREA_XY,SECTIONS_PER_AREA_Z,workGroupZ);

    uint cascadeLevel= bool(workGroupID.x&1u) ? getSecondaryCascadeLevel() : 0;
    if(cascadeLevel>=NUM_CASCADES) return;


    uint layer = workGroupID.z%VOX_LAYERS;
    axis = workGroupID.z/VOX_LAYERS;

    ivec3 zonePos = ivec3(ivec2(localID.x,workGroupID.y)-1, -1);
    scale = getScale(cascadeLevel);
    ivec3 areaShift = getAreaShift(scale);

    zoneShift = areaToZoneSpace(areaShift,axis);
    zoneMemOffset = zoneOffset(axis,layer,cascadeLevel);
    upZoneMemOffset = (cascadeLevel<NUM_CASCADES-1)?zoneOffset(axis,layer,cascadeLevel+1) : 0;
    upZoneShift = areaToZoneSpace(getAreaShift(scale*2),axis);
    ivec3 zoneMovement = areaToZoneSpaceRelative(areaShift - getPreviousAreaShift(scale),axis);

    if(localID==ivec3(0)){

    }

    if(axis==2){
//        if (layer==0)
//            sunlight(zonePos);
//        else
//            nullify(zonePos);
    }else{
        //        nullify(texelPos);
    }

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