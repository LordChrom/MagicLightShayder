#define READS_LIGHT_LIST
#define READS_BASE_VOX
#include "/lib/voxelStorage/volumeShifting.glsl"
#include "/lib/voxelStorage/blockPacking.glsl"
#include "/lib/voxelStorage/vsAccess.glsl"
#include "/lib/lighting/swrt/lightListAccess.glsl"
#include "/lib/util/uniforms/frameCounter"
#include "/lib/lighting/distanceFalloff.glsl"
#include "/lib/lighting/swrt/rayIntersect.glsl"

#include "/lib/util/wideFilteredSample.glsl"


#define TEMPORAL_DITHER
#include "/lib/util/dither.glsl"

ivec3 unitShift;

vec3 colorOfPackedLight(uint light){
    return worldVoxColor((light>>22)&0x3fu,(light>>28)&0x3fu);
}

ivec3 worldPosToSWRT(vec3 pos){
    ivec3 ret = ivec3(floor(pos))-ivec3(floor(globalOrigin));
    ret+=SWRT_SIZE>>1;
    return ret;
}


vec3 penumbraNoise(float ditherValue){
    vec3 sourcePosNoise = vec3(ditherValue,recycleNoise(ditherValue),0);
    sourcePosNoise.z=recycleNoise(sourcePosNoise.y);
    return 0.25*(sourcePosNoise-0.5);
}

vec4 traceLight(vec3 worldPos,ivec3 areaPos,uint light,uint maxSteps){
    ivec3 lightPosRel = uncheckedUnpackListedLight(light);
    vec3 displacementToLight = lightPosRel-fract(worldPos)+0.5;

    float lightStr = lightFalloff(displacementToLight);

    bool hitObstruction = traceRay(worldPos,displacementToLight,unitShift,maxSteps)>=0;
    return vec4(colorOfPackedLight(light)*lightStr,!hitObstruction);
}


vec4 swrtSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue, uint maxSteps){
    worldPos+=clamp(length(worldPos-globalOrigin)*0.001,0.04,0.1)*normal;
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
        float mult = float(numLights)/(4*SWRT_LIGHT_LAYERS);
        numLights = ((numLights-1)%7)+1;
        return vec4(mult*((ivec3(numLights)>>ivec3(2,1,0))&1),1);
    }
    #endif

    areaPos+=offsetToVox;

    vec4 color = vec4(0);


    for(uint rayNum=0;rayNum<3;rayNum++){
        vec3 displacementToLight, sampleColor;
        {
            uint baseIndex = rayNum+(rayNum>>1); //0,1,3
            if(baseIndex>numLights)
                break;

            int numLightsToChooseFrom = 1<<rayNum;//1,2,4
            uint lightIndex = clamp(uint(ditherValue*numLightsToChooseFrom),0u,uint(numLightsToChooseFrom-1))+baseIndex;

            displacementToLight = uncheckedUnpackListedLight(lights[lightIndex])-fract(worldPos)+0.5;

            float lightStr = numLightsToChooseFrom*lightFalloff(displacementToLight);
            lightStr*=normalFactor(normal,displacementToLight,0);
            sampleColor = colorOfPackedLight(lights[lightIndex])*lightStr;

            #ifdef SWRT_NOISY_PENUMBRAS
            displacementToLight+=penumbraNoise(ditherValue);
            #endif
        }

        if(traceRay(worldPos,displacementToLight,unitShift,maxSteps)<0){
            color.rgb+=sampleColor;
            color.a++;
        }
    }

    return color;
}

uniform sampler2D swrtRayHitSampler;

vec3 shadePrehitRays(vec3 worldPos, vec3 normal, float subsurface, vec2 tc){
    worldPos+=clamp(length(worldPos-globalOrigin)*0.001,0.04,0.1)*normal;
    normal=-normal;
    unitShift = getUnitShift();
    ivec3 areaPos = worldPosToSWRT(worldPos);

    if(areaPos.x<0||areaPos.y<0||areaPos.z<0||
    areaPos.x>=SWRT_SIZE||areaPos.y>=SWRT_SIZE||areaPos.z>=SWRT_SIZE
    ){
        return vec3(0);
    }

    #ifdef DEBUG_SWRT_LIGHT_COUNT
    if(true){
        uint[SWRT_LIGHTS_PER_BLOCK] fullLightList;
        getLightList(fullLightList,areaPos,unitShift);
        uint numLights = countLights(fullLightList);

        float mult = float(numLights)/(4*SWRT_LIGHT_LAYERS);
        numLights = ((numLights-1)%7)+1;
        return vec3(mult*((ivec3(numLights)>>ivec3(2,1,0))&1));
    }
    #endif

    areaPos+=offsetToVox;

    vec3 color = vec3(0);


    uvec4 lightShortList;
    for(uint i=0;i<SWRT_LIGHTS_PER_BLOCK;i++){
        if((i&3u)==0u)
            lightShortList = getLightListLayer(areaPos, unitShift, i>>2);

        vec2 tempTc = tc;
        tempTc.x+=float(i)/SWRT_LIGHTS_PER_BLOCK;
        tempTc+=(0.5/textureSize(swrtRayHitSampler,0))*((ivec2(i>>1,i)&1));

        #if SWRT_NOISE_FILTER>=0
        vec2 ts = textureSize(swrtRayHitSampler,0);
        tempTc = mix(tempTc,round(tempTc*ts)/ts,0.7);
        #endif

        #if SWRT_TRANSLUCENCY>0
            #if SWRT_NOISE_FILTER<=1
            vec3 visibility = texture(swrtRayHitSampler,tempTc).rgb;
            #else
            vec3 visibility = wideSample(swrtRayHitSampler,tempTc).rgb;
            #endif
        #else
             #if SWRT_NOISE_FILTER<=1
            float visibility = texture(swrtRayHitSampler,tempTc).x;
            #else
            float visibility = wideSample(swrtRayHitSampler,tempTc).x;
            #endif
        #endif

        uint light = lightShortList[i&3u];
        vec3 displacementToLight = uncheckedUnpackListedLight(light)-fract(worldPos)+0.5;

        float lightStr = lightFalloff(displacementToLight);
        lightStr*=normalFactor(normal,displacementToLight,0);

        if(lightStr>0)
            color.rgb+=colorOfPackedLight(light)*visibility*lightStr;
    }

    return color;
}


vec3 swrtSampleFog(vec3 worldPos){
    unitShift = getUnitShift();
    ivec3 areaPos = worldPosToSWRT(worldPos);


    if(areaPos.x<0||areaPos.y<0||areaPos.z<0||
        areaPos.x>=SWRT_SIZE||areaPos.y>=SWRT_SIZE||areaPos.z>=SWRT_SIZE
    ){
        return vec3(0);
    }

    areaPos+=offsetToVox;

    uint i=0;
    uvec4 lightShortList;
    vec3 color = vec3(0);


    #if SWRT_RAYS_PER_FOG_SAMPLE>0
    lightShortList = getLightListLayer(areaPos, unitShift, 0);
    for(i=0;i<SWRT_RAYS_PER_FOG_SAMPLE;i++){
        uint light = lightShortList[i&3u];
        if(!bool(light&LIGHT_VALID_BIT))
            break;

        vec4 hitColor = traceLight(worldPos,areaPos,light,10u);
        color += hitColor.rgb*hitColor.a;
    }
    #endif

    worldPos = 0.5-fract(worldPos);

    #define FOG_SWRT_LIGHTS SWRT_LIGHTS_PER_BLOCK
    #define FOG_SWRT_LIGHTS 4
    for(;i<FOG_SWRT_LIGHTS;i++){
        if((i&3u)==0u)
            lightShortList = getLightListLayer(areaPos, unitShift, i>>2);
        uint light = lightShortList[i&3u];
        if(!bool(light&LIGHT_VALID_BIT))
            break;

        vec3 displacementToLight = uncheckedUnpackListedLight(light)+worldPos;

        color+= colorOfPackedLight(light)*lightFalloff(displacementToLight);
    }

    return color;
}