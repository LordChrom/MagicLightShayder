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

ivec3 unitShift;

vec3 colorOfPackedLight(uint light){
    return worldVoxColor((light>>16)&0x3fu,(light>>28)&0x3fu);
}
ivec3 worldPosToSWRT(vec3 pos){
    ivec3 ret = ivec3(floor(pos))-ivec3(floor(globalOrigin));
    ret+=SWRT_SIZE>>1;
    return ret;
}

float depthTillChange(float value, float differential){
    return (1-fract(value*sign(differential)))/abs(differential);

}

float minDepthTillChange(vec3 value, vec3 differential){
    value = 1-fract(value*sign(differential));
    value/=abs(differential);
    return min(min(value.x,value.y),value.z);
}

float traceRay(vec3 worldPos, vec3 worldDirToLight, uint maxSteps){
    worldPos+=(VOXELIZATION_SIZE>>1)-unitShift;

    ivec3 finalBlock = ivec3(floor(worldPos+worldDirToLight));

    float maxTraceDepth = length(worldDirToLight);
    worldDirToLight=normalize(worldDirToLight);

    const float nudge = 0.0001;



    float depth = nudge;
    for(int i=0;i<maxSteps && depth<maxTraceDepth;i++){
        vec3 samplePosition = worldPos+depth*worldDirToLight;
        ivec3 areaPos = ivec3(floor(samplePosition));
        uint voxel = getBaseVoxData(areaPos,unitShift);
        float nextDepthDif = minDepthTillChange(samplePosition,worldDirToLight)+nudge;

        if(areaPos==finalBlock)
            break;

        if(bool(voxel&WORLDVOX_OPAQUE))
            return depth;

        depth+=nextDepthDif;
    }

    return -1;
}

void penumbraNoise(inout vec3 position,float ditherValue){
    vec3 sourcePosNoise = vec3(ditherValue,recycleNoise(ditherValue),0);
    sourcePosNoise.z=recycleNoise(sourcePosNoise.y);
    position += 0.25*(sourcePosNoise-0.5);
}

//check if valid BEFORE using
//vec4 traceLight(vec3 worldPos,ivec3 areaPos, ivec3 unitShift,ivec3 lightPosRel,float ditherValue,uint maxSteps,vec3 normal){
//    vec3 displacementToLight = lightPosRel-fract(worldPos)+0.5;
//    uint voxel = getBaseVoxData(areaPos+lightPosRel,unitShift);
//
//    float lightStr = lightFalloff(displacementToLight)*normalFactor(-normal,displacementToLight,0);
////    if(lightStr<=0.01)
////        return vec4(0);
//
//    #ifdef SWRT_NOISY_PENUMBRAS
//    penumbraNoise(displacementToLight,ditherValue);
//    #endif
//
//
//    bool hitObstruction = traceRay(worldPos,displacementToLight,unitShift,maxSteps)>=0;
//    return vec4(worldVoxColor(voxel)*lightStr,!hitObstruction);
//}
vec4 traceLight(vec3 worldPos,ivec3 areaPos,uint light,float ditherValue,uint maxSteps){
    ivec3 lightPosRel = uncheckedUnpackListedLight(light);
    vec3 displacementToLight = lightPosRel-fract(worldPos)+0.5;

    float lightStr = lightFalloff(displacementToLight);

    #ifdef SWRT_NOISY_PENUMBRAS
    penumbraNoise(displacementToLight,ditherValue);
    #endif


    bool hitObstruction = traceRay(worldPos,displacementToLight,maxSteps)>=0;
    return vec4(colorOfPackedLight(light)*lightStr,!hitObstruction);
}


vec4 swrtSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue, uint maxSteps){
    worldPos+=0.02*normal;
    normal=-normal;
    unitShift = getUnitShift();
    ivec3 areaPos = worldPosToSWRT(worldPos);

    if(areaPos.x<0||areaPos.y<0||areaPos.z<0||
        areaPos.x>=SWRT_SIZE||areaPos.y>=SWRT_SIZE||areaPos.z>=SWRT_SIZE
    ){
        return vec4(0);
    }

    uint[SWRT_LIGHTS_PER_BLOCK] lights;
    getLightList(lights,areaPos,unitShift);
    uint numLights = countLights(lights);

    #ifdef DEBUG_SWRT_LIGHT_COUNT
    if(true){
//        numLights=clamp(numLights,0,7);
        float mult = float(numLights)/(4*SWRT_LIGHT_LAYERS);
        numLights = ((numLights-1)%7)+1;
        return vec4(mult*((ivec3(numLights)>>ivec3(2,1,0))&1),1);
    }
    #endif

    areaPos+=offsetToVox;

    vec4 color = vec4(0);


    for(uint rayNum=0;rayNum<3;rayNum++){
        uint baseIndex = rayNum+(rayNum>>1); //0,1,3
        if(baseIndex>numLights)
            break;

        int numLightsToChooseFrom = 1<<rayNum;//1,2,4
        uint lightIndex = clamp(uint(ditherValue*numLightsToChooseFrom),0u,uint(numLightsToChooseFrom-1))+baseIndex;

        ivec3 sourceRel = uncheckedUnpackListedLight(lights[lightIndex]);
//        vec4 traceColor = traceLight(worldPos,areaPos,unitShift,sourceRel,ditherValue,maxSteps,normal);

        vec3 displacementToLight = sourceRel-fract(worldPos)+0.5;
        uint voxel = getBaseVoxData(areaPos+sourceRel,unitShift);

        float lightStr = lightFalloff(displacementToLight);
        lightStr*=normalFactor(normal,displacementToLight,0);

        #ifdef SWRT_NOISY_PENUMBRAS
        penumbraNoise(displacementToLight,ditherValue);
        #endif

        bool hitObstruction = traceRay(worldPos,displacementToLight,maxSteps)>=0;
        vec4 traceColor = vec4(worldVoxColor(voxel)*lightStr,!hitObstruction);

        traceColor.rgb*=traceColor.a*numLightsToChooseFrom;

        color.rgb+=traceColor.rgb;
        color.a++;
    }

    return color;
}

vec3 swrtSampleFog(vec3 worldPos, float ditherValue, uint maxSteps){
    unitShift = getUnitShift();
    ivec3 areaPos = worldPosToSWRT(worldPos);

    vec3 color = vec3(0);

    if(areaPos.x<0||areaPos.y<0||areaPos.z<0||
        areaPos.x>=SWRT_SIZE||areaPos.y>=SWRT_SIZE||areaPos.z>=SWRT_SIZE
    ){
        return color;
    }

    uint[SWRT_LIGHTS_PER_BLOCK] lights;
    getLightList(lights,areaPos,unitShift);
    areaPos+=offsetToVox;

    uint numLights = countLights(lights);

    if(numLights==0)
        return color;

    int i=0;
    const int raysPerFogSample = 0;
    for(i=0;i<min(raysPerFogSample,numLights);i++){
        vec4 hitColor = traceLight(worldPos,areaPos,lights[i],ditherValue,maxSteps);
        color += hitColor.rgb*hitColor.a;
    }



    for(;i<numLights;i++){
        ivec3 lightPosRel = uncheckedUnpackListedLight(lights[i]);
        vec3 displacementToLight = lightPosRel-fract(worldPos);
        float lightStr = lightFalloff(displacementToLight+0.5);

        color+= colorOfPackedLight(lights[i])*lightStr;
    }

    return color;
}