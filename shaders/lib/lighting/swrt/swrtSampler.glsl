#define READS_LIGHT_LIST
#define READS_BASE_VOX
#include "/lib/voxelStorage/volumeShifting.glsl"
#include "/lib/voxelStorage/blockPacking.glsl"
#include "/lib/voxelStorage/vsAccess.glsl"
#include "/lib/lighting/swrt/lightListAccess.glsl"
#include "/lib/util/uniforms/frameCounter"
#include "/lib/lighting/distanceFalloff.glsl"

#define TEMPORAL_DITHER
#include "/lib/util/dither.glsl"


ivec3 worldPosToSWRT(vec3 pos){
    ivec3 ret = ivec3(floor(pos))-ivec3(floor(globalOrigin));
    ret+=SWRT_SIZE>>1;
    return ret;
}

bool traceRayToOneLight(vec3 worldPos, vec3 worldDirToLight, ivec3 unitShift, uint maxSteps){
    ivec3 finalBlock = ivec3(floor(worldPos+worldDirToLight))+(VOXELIZATION_SIZE>>1)-unitShift;

    float maxTraceDepth = length(worldDirToLight);
    worldDirToLight=normalize(worldDirToLight);



    float depth = 0;
    for(int i=0;i<maxSteps && depth<maxTraceDepth;i++){
        depth+=0.0001;
        vec3 samplePosition = worldPos+depth*worldDirToLight;
        ivec3 areaPos = ivec3(floor(samplePosition))+(VOXELIZATION_SIZE>>1)-unitShift;
        uint voxel = getBaseVoxData(areaPos,unitShift);

        if(areaPos==finalBlock)
            return false;


        if(bool(voxel&WORLDVOX_OPAQUE))
                return true;

        vec3 depthTillPxEdge = (1-fract(samplePosition*sign(worldDirToLight)))/abs(worldDirToLight);
        depth+=min(min(depthTillPxEdge.x,depthTillPxEdge.y),depthTillPxEdge.z);
    }

    return false;
}

//check if valid BEFORE using
vec4 traceToLight(vec3 worldPos,ivec3 areaPos, ivec3 unitShift,ivec3 lightPosRel,float ditherValue,uint maxSteps){
    #ifdef SWRT_NOISY_PENUMBRAS
    vec3 sourcePosNoise = vec3(ditherValue,recycleNoise(ditherValue),0);
    sourcePosNoise.z=recycleNoise(sourcePosNoise.y);
    sourcePosNoise = 0.375+0.25*sourcePosNoise;
    #else
    vec3 sourcePosNoise = vec3(0.5);
    #endif

    vec3 displacementToLight = lightPosRel-fract(worldPos);
    float lightStr = lightFalloff(displacementToLight+0.5);
    displacementToLight+=sourcePosNoise;
    ivec3 lightPos = areaPos+lightPosRel;

    bool hitObstruction = traceRayToOneLight(worldPos,displacementToLight,unitShift,maxSteps);
    uint voxel = getBaseVoxData(lightPos,unitShift);
    return vec4(worldVoxColor(voxel)*lightStr,!hitObstruction);
}

vec3 swrtSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue, uint maxLights, uint maxSteps){
    worldPos+=0.01*normal;
    ivec3 unitShift = getUnitShift();
    ivec3 swrtPos = worldPosToSWRT(worldPos);

    if(swrtPos.x<0||swrtPos.y<0||swrtPos.z<0||
        swrtPos.x>=SWRT_SIZE||swrtPos.y>=SWRT_SIZE||swrtPos.z>=SWRT_SIZE
    ){
        return vec3(0);
    }

    uvec4 list = getLightList(swrtPos,unitShift);
    ivec3 areaPos = swrtPos+offsetToVox;


    uint numLights = countLights(list);
    numLights=min(numLights,maxLights);

    vec3 color = vec3(0);

    #ifdef SWRT_NOISY_PENUMBRAS
    ditherValue = temporalNoise(ditherValue);
    #endif

    for(int i=int(numLights)-1;i>=0;i--){
        uint source = getNthLight(list,uint(i));
        vec4 hitColor = traceToLight(worldPos,areaPos,unitShift,uncheckedUnpackListedLight(source),ditherValue,maxSteps);
        color+= hitColor.rgb*hitColor.a;
    }

    return color;
}

vec3 swrtSampleFog(vec3 worldPos, vec3 normal, float subsurface, float ditherValue, uint maxSteps){
    worldPos+=0.01*normal;
    ivec3 unitShift = getUnitShift();
    ivec3 swrtPos = worldPosToSWRT(worldPos);

    if(swrtPos.x<0||swrtPos.y<0||swrtPos.z<0||
    swrtPos.x>=SWRT_SIZE||swrtPos.y>=SWRT_SIZE||swrtPos.z>=SWRT_SIZE
    ){
        return vec3(0);
    }

    uvec4 list = getLightList(swrtPos,unitShift);
    ivec3 areaPos = swrtPos+offsetToVox;


    uint numLights = countLights(list);
    if(numLights==0)
        return vec3(0);

    vec3 color = vec3(0);
    int i=0;
    for(i=0;i<min(1,numLights);i++){
        uint source = getNthLight(list,i);
        vec4 hitColor = traceToLight(worldPos,areaPos,unitShift,uncheckedUnpackListedLight(source),ditherValue,maxSteps);
        color += hitColor.rgb*hitColor.a;
    }



    for(;i<numLights;i++){
        uint source = getNthLight(list,uint(i));
        ivec3 lightPosRel = uncheckedUnpackListedLight(source);
        uint voxel = getBaseVoxData(lightPosRel+areaPos,unitShift);
        vec3 displacementToLight = lightPosRel-fract(worldPos);
        float lightStr = lightFalloff(displacementToLight+0.5);

        color+= worldVoxColor(voxel)*lightStr;
    }

    return color;
}