#version 430 compatibility
#define SAMPLES_LIGHT_FACE
#define WRITES_LIGHT_FACE

#include "/lib/lighting/floodShadows/fsHelper.glsl"
#if 0
#define PackedLight uvec4
#endif

uniform int heightLimit;
uniform int bedrockLevel;
uniform vec3 cameraPosition;
#if VOXELIZATION_MODE==1
uniform mat4 gbufferModelView, gbufferProjection;
#endif



//one for each axis * layer combo, and also one for the world
//TODO remove the world one
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

const ivec3 workGroups = ivec3(NUM_CASCADES,AREA_SIZE,AXIS_LAYER_WORLD_COUNT);
layout (local_size_x = AREA_SIZE, local_size_y = 1, local_size_z = 1) in;


float scale = 0.0;

uint thisMemOffset  = 0;
uint upperMemOffset = 0;
uint axis           = 0;
uint cascadeLevel   = 0;
uint frameOffset    = 0;

ivec3 thisShift  = ivec3(0);
ivec3 upperShift = ivec3(0);
ivec3 movement   = ivec3(0);
bool cascadeVisitedThisFrame = false;

void trimLight(ivec3 zonePos){
    PackedLight light = PackedLight(0);

    vec3 zonePosRemnants;
    ivec3 upZonePos = uppperCascadeZonePos(zonePos,thisShift,axis,scale,zonePosRemnants);

    //TODO check if position in higher volume hasnt been shifted out of bounds, but should only be an issue when moving *very* fast
    bool upsampleValid = bool(~upperMemOffset);
    if(upsampleValid){
        light = sampleLightData(upZonePos,upperShift,upperMemOffset);
    }
    setLightData(light, ivec3(zonePos), thisShift, thisMemOffset);
}

void fillLightSeams(){
    uint layer = gl_WorkGroupID.z%VOX_LAYERS;
    axis = gl_WorkGroupID.z/VOX_LAYERS;
#if DEBUG_AXIS>=0
    axis = DEBUG_AXIS;
#endif

    ivec2 zonePos = ivec2(gl_LocalInvocationID.x,gl_WorkGroupID.y);
    movement = areaToZoneSpaceRelative(movement,axis);
    thisShift = areaToZoneSpace(thisShift,axis);

    thisMemOffset = zoneOffset(axis,layer,cascadeLevel);
    upperMemOffset = (cascadeLevel<NUM_CASCADES-1)?zoneOffset(axis,layer,cascadeLevel+1) : ~0;
    upperShift = areaToZoneSpace(getAreaShift(scale*2),axis);

    //TODO make do outward light

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

void main(){
    cascadeLevel = gl_WorkGroupID.x;
    frameOffset = frameCounter;
    uint bonusCascadeLevel = getVariableCascadeLevel(frameOffset,false);

    scale = getScale(cascadeLevel);

    thisShift = getAreaShift(scale);
    upperShift = getAreaShift(scale*2);

    cascadeVisitedThisFrame = cascadeLevel==bonusCascadeLevel;
#ifdef DOUBLE_PROC
    if(cascadeLevel==0)
        cascadeVisitedThisFrame=true;
#endif

    ivec3 previousAreaShift = getPreviousAreaShift(scale);

    movement = clamp(thisShift-previousAreaShift,-AREA_SIZE,AREA_SIZE);

    if(gl_WorkGroupID.z==(AXIS_LAYER_WORLD_COUNT-1))
        return;
    fillLightSeams();
}