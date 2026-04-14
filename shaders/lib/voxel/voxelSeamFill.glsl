#define SAMPLES_LIGHT_FACE
#define WRITES_LIGHT_FACE
#define SAMPLES_VOX
#define WRITES_VOX
#include "/lib/voxel/voxelHelper.glsl"

uniform int heightLimit;
uniform int bedrockLevel;
uniform bool hasCeiling;
uniform vec3 cameraPosition;
#if VOXELIZATION_MODE==1
uniform mat4 gbufferModelView, gbufferProjection;
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

#ifdef LAZY_SEAMFILLER
    const ivec3 workGroups = ivec3(PROC_MULT,AREA_SIZE_MEM,AXIS_LAYER_WORLD_COUNT);
#else
    const ivec3 workGroups = ivec3(NUM_CASCADES,AREA_SIZE_MEM,AXIS_LAYER_WORLD_COUNT);
#endif
layout (local_size_x = AREA_SIZE_MEM, local_size_y = 1, local_size_z = 1) in;

const vec3 sunColor = vec3(242,242,242)/255;
const vec3 sunPos = vec3(0,0,1000);
const uvec4 noLight = uvec4(0);
uvec4 defaultSunLight = packLightData(vec2(0),0xfu,sunColor,vec3(0,0,10),0f,1,0xfeu);

const int workGroupZ = 6*PROC_MULT;



layout(std430, binding = 0) restrict buffer areaData {
    areaMeta[NUM_CASCADES] oddAreaMetas;
    areaMeta[NUM_CASCADES] evenAreaMetas;
} areaDataAccess;

layout(std430, binding = 1) restrict buffer indirectDispatches {
    uvec3 lighterDispatches;
} indirectDispatchesAccess;

float scale;
uint thisMemOffset, upperMemOffset, axis, cascadeLevel;
ivec3 thisShift, upperShift, movement;
bool cascadeVisitedThisFrame;

void trimLight(ivec3 zonePos){
    uvec4 light = noLight;

    ivec3 upZonePos = (zonePos+(1&(thisShift))+(AREA_SIZE/2));
    vec3 zonePosRemnants= -0.5+vec3(1&upZonePos);
    upZonePos>>=1;

    //TODO check if position in higher volume hasnt been shifted out of bounds, but should only be an issue when moving *very* fast
    bool upsampleValid = bool(upperMemOffset);
    if(upsampleValid){
        light = sampleLightData(upZonePos,upperShift,upperMemOffset);
        if(unpackLightType(light)!=LIGHT_TYPE_SUN)
            setPackedLightTravel(light,unpackLightTravel(light)+zonePosRemnants);
    }
#ifndef DEBUG_DISABLE_SUN
    if((!hasCeiling) && axis==2 && zonePos.z<=0){
        float height = getGlobalOrigin(scale).y+0.5*scale*AREA_SIZE;
        if(height>=(heightLimit+bedrockLevel) || (cascadeLevel==(NUM_CASCADES-1)))
            light = defaultSunLight;
    }
#endif
    setLightData(light, ivec3(zonePos), thisShift, thisMemOffset);
}

void fillLightSeams(uvec3 workGroupID, uvec3 localID){
    uint layer = workGroupID.z%VOX_LAYERS;
    axis = workGroupID.z/VOX_LAYERS;

    ivec3 zonePos = ivec3(ivec2(localID.x,workGroupID.y)-1, -1);
    movement = areaToZoneSpaceRelative(movement,axis);
    thisShift = areaToZoneSpace(thisShift,axis);

    thisMemOffset = zoneOffset(axis,layer,cascadeLevel);
    upperMemOffset = (cascadeLevel<NUM_CASCADES-1)?zoneOffset(axis,layer,cascadeLevel+1) : 0;
    upperShift = areaToZoneSpace(getAreaShift(scale*2),axis);

    //TODO consider only do the recetnly updated ones
    //TODO make do outward light
    trimLight(ivec3(zonePos.xy,-1));
    trimLight(ivec3(AREA_SIZE+1,zonePos.xy));
    trimLight(ivec3(         -1,zonePos.xy));
    trimLight(ivec3(zonePos.x,AREA_SIZE+1,zonePos.y));
    trimLight(ivec3(zonePos.x,         -1,zonePos.y));


    ivec3 movementSigns = sign(movement);
    ivec3 edgeToTrim = abs(movement);

    for(int i=0; i<edgeToTrim.z;i++){
        int L = movementSigns.z>0?(AREA_SIZE-1)-i:i;
        trimLight(ivec3(zonePos.xy,L));
    }

    for(int i=0; i<edgeToTrim.x;i++){
        int A = movementSigns.x>0?(AREA_SIZE-1)-i:i;
        trimLight(ivec3(A,zonePos.xy));
    }

    for(int i=0; i<edgeToTrim.y;i++){
        int B = movementSigns.y>0?(AREA_SIZE-1)-i:i;
        trimLight(ivec3(zonePos.x,B,zonePos.y));
    }


}



bool isPosExpiryExempt(ivec3 areaPos){
#if VOXELIZATION_MODE == 1
    vec3 pos = vec3(areaPos-(AREA_SIZE>>1))*scale+0.5;
    vec4 clipSpace = gbufferProjection*vec4((gbufferModelView*vec4(pos,1)).xyz,1);
    clipSpace.w*=1.15;

    return (clipSpace.x<-clipSpace.w || clipSpace.x>clipSpace.w)||
        (clipSpace.y<-clipSpace.w || clipSpace.y>clipSpace.w)||
        (clipSpace.z<-clipSpace.w || clipSpace.z>clipSpace.w);
#else
    return false;
#endif
}

void fillVoxSeams(uvec3 workGroupID, uvec3 localID){
    indirectDispatchesAccess.lighterDispatches=uvec3(SECTIONS_PER_AREA_XY,SECTIONS_PER_AREA_Z,workGroupZ);

    thisMemOffset = areaOffset(cascadeLevel);
    upperMemOffset = (cascadeLevel<NUM_CASCADES-1)?areaOffset(cascadeLevel+1):0;


    ivec2 posXY = ivec2(localID.x,workGroupID.y)-1;

    ivec3 movementSigns = sign(movement);
    ivec3 edgeToTrim = abs(movement);


    for(ivec3 areaPos = ivec3(posXY,-1); areaPos.z<AREA_SIZE_MEM; areaPos.z++){
        uint whatToWrite = 0u;
        if(!(
            (movementSigns.x>0?(areaPos.x>(AREA_SIZE-1)-edgeToTrim.x):(areaPos.x<edgeToTrim.x)) ||
            (movementSigns.y>0?(areaPos.y>(AREA_SIZE-1)-edgeToTrim.y):(areaPos.y<edgeToTrim.y)) ||
            (movementSigns.z>0?(areaPos.z>(AREA_SIZE-1)-edgeToTrim.z):(areaPos.z<edgeToTrim.z))
        )){
            if(isPosExpiryExempt(areaPos))
                continue;
            whatToWrite=getVoxData(areaPos,thisShift,thisMemOffset);
    #ifndef DEBUG_NOTHING_EXPIRES
            whatToWrite-=(uint(bool(whatToWrite))<<VOXEL_AGE_SHIFT);
            whatToWrite = bool(whatToWrite&VOXEL_AGE_MASK)?whatToWrite:0;
    #endif
        }
        setVoxData(whatToWrite,areaPos,thisShift,thisMemOffset);
    }

    if(0<=posXY.x && posXY.x<AREA_SIZE && 0<=posXY.y && posXY.y<AREA_SIZE){
        if(upperMemOffset==0) return;

        ivec3 areaPos = ivec3(posXY&~1,(((posXY.x&1)<<1)+((posXY.y&1)<<2)+(frameCounter<<3))%AREA_SIZE);
        uint representative = 0;
        for(int i=0; i<8; i++){
            ivec3 subPos = ivec3(i,i>>1,i>>2)&1;
            uint sampledVox = getVoxData(areaPos+subPos, thisShift, thisMemOffset);
            representative = max(representative,sampledVox);
        }

        areaPos=(areaPos>>1)+ivec3(1,1,1)*(AREA_SIZE>>2);
        updateVoxData(representative, areaPos, upperShift, upperMemOffset);
    }else{
        //TODO make it do the inward blocks
    }
}

void fillSeams(uvec3 workGroupID, uvec3 localID){
#ifdef LAZY_SEAMFILLER
    cascadeLevel = getVariableCascadeLevel(bool(workGroupID.x&1u));
    if(cascadeLevel>=NUM_CASCADES) return;
#else
    cascadeLevel = workGroupID.x;
    uint bonusCascadeLevel = getVariableCascadeLevel(false);
#endif

    scale = getScale(cascadeLevel);

    thisShift = getAreaShift(scale);
    upperShift = getAreaShift(scale*2);

#ifdef LAZY_SEAMFILLER
    #ifdef DOUBLE_PROC
    int nextCascade = (1<<cascadeLevel);
    #else
    int nextCascade = (2<<cascadeLevel);
    #endif
    bool isOddVisit = bool(frameCounter&nextCascade);
    cascadeVisitedThisFrame=true;
#else
    cascadeVisitedThisFrame = cascadeLevel==bonusCascadeLevel;
    #ifdef DOUBLE_PROC
    if(cascadeLevel==0)
        cascadeVisitedThisFrame=true;
    #endif
    bool isOddVisit = bool(frameCounter&1);
#endif


    ivec3 previousAreaShift = ivec3(0);

    if(isOddVisit){
        previousAreaShift = areaDataAccess.evenAreaMetas[cascadeLevel].areaShift;
        if(localID.x==0)
            areaDataAccess.oddAreaMetas[cascadeLevel].areaShift = thisShift;
    }else{
        previousAreaShift = areaDataAccess.oddAreaMetas[cascadeLevel].areaShift;
        if(localID.x==0)
            areaDataAccess.evenAreaMetas[cascadeLevel].areaShift = thisShift;
    }

    movement = clamp(thisShift-previousAreaShift,-AREA_SIZE_MEM,AREA_SIZE_MEM);

    if(workGroupID.z==(AXIS_LAYER_WORLD_COUNT-1)){
        if(!cascadeVisitedThisFrame)
            return;
        fillVoxSeams(workGroupID, localID);
    }else
        fillLightSeams(workGroupID,localID);
}