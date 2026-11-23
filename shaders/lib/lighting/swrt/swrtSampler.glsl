#define READS_LIGHT_LIST
#define READS_BASE_VOX
#include "/lib/voxelStorage/volumeShifting.glsl"
#include "/lib/voxelStorage/blockPacking.glsl"
#include "/lib/voxelStorage/vsAccess.glsl"
#include "/lib/lighting/swrt/lightListAccess.glsl"
#include "/lib/util/uniforms/frameCounter"
#include "/lib/lighting/distanceFalloff.glsl"
#include "/lib/util/wideFilteredSample.glsl"


#define TEMPORAL_DITHER
#include "/lib/util/dither.glsl"


vec3 colorOfPackedLight(uint light){
    return worldVoxColor((light>>22)&0x3fu,(light>>28)&0x3fu);
}

ivec3 worldPosToSWRT(vec3 pos){
    ivec3 ret = ivec3(floor(pos))-unitShift;
    ret+=SWRT_SIZE>>1;
    return ret;
}


vec3 penumbraNoise(float ditherValue){
    vec3 sourcePosNoise = vec3(ditherValue,recycleNoise(ditherValue),0);
    sourcePosNoise.z=recycleNoise(sourcePosNoise.y);
    return SWRT_PENUMBRA_SIZE*(sourcePosNoise-0.5);
}

#ifdef SWRT_INCLUDE_TRACE
#include "/lib/lighting/swrt/rayIntersect.glsl"
#endif

uniform sampler2D swrtRayHitSampler;

#ifdef VOXEL_COMPOSITE_SHADER
vec4 shadePrehitRays(vec3 worldPos, vec3 normal, float subsurface, vec2 tc){
    worldPos+=clamp(length(worldPos-globalOrigin)*0.001,0.04,0.1)*normal;
    normal=-normal;

    ivec3 areaPos = worldPosToSWRT(worldPos);

    if(areaPos.x<0||areaPos.y<0||areaPos.z<0||
    areaPos.x>=SWRT_SIZE||areaPos.y>=SWRT_SIZE||areaPos.z>=SWRT_SIZE
    ){
        #ifdef DEBUG_SWRT_DIST
        return vec4(1,0,0.2,0);
        #else
        return vec4(0f);
        #endif
    }

    #ifdef DEBUG_SWRT_LIGHT_COUNT
    if(true){
        uint[SWRT_LIGHTS_PER_BLOCK] fullLightList;
        getLightList(fullLightList,areaPos);
        uint numLights = countLights(fullLightList);

        float mult = float(numLights)/(4*SWRT_LIGHT_LAYERS);
        numLights = ((numLights-1)%7)+1;
        return vec4(mult*((ivec3(numLights)>>ivec3(2,1,0))&1),0f);
    }
    #endif

    areaPos+=offsetToVox;

    vec4 color = vec4(0f);

    float blockPosHash = float(((areaPos.x*53)^(areaPos.y*17)^(areaPos.z*97))%255)/255.0;

    //xoring with subgroup invocation ID will get the one thats clockwise in the 2x2 group
    uint goClockwise = ((gl_SubgroupInvocationID&5u)==1u) || ((gl_SubgroupInvocationID&5u)==4u)?1u:4u;

    uvec4 lightShortList;
    for(uint i=0;i<SWRT_LIGHTS_PER_BLOCK;i++){
        if((i&3u)==0u)
            lightShortList = getLightListLayer(areaPos, i>>2);

        vec2 tempTc = tc;
        tempTc.x+=float(i)/SWRT_LIGHTS_PER_BLOCK;

        vec2 diagTc = subgroupShuffleXor(tempTc,5u);
        vec2 backupTc =  2.5*tempTc-1.5*diagTc;
        vec2 quadCenter=0.5*(tempTc+diagTc);

        //of the two directly adjacent source texels, this gets the counterclockwise one
        backupTc = bool(goClockwise&1u)?vec2(2.5*tempTc.x-1.5*diagTc.x,quadCenter.y) : vec2(quadCenter.x,2.5*tempTc.y-1.5*diagTc.y);
        vec4 visibility = texture(swrtRayHitSampler,tempTc);
        vec4 centerBackupVis = texture(swrtRayHitSampler,quadCenter);
        vec4 outerBackupA = texture(swrtRayHitSampler,backupTc);


        uint light = lightShortList[i&3u];
        if(!bool(light&LIGHT_VALID_BIT))
            break;

        vec3 displacementToLight = displacementToListedLight(light,worldPos.xyz);

        float lightStr = lightFalloff(displacementToLight);
        lightStr*=normalFactor(normal,displacementToLight,0);

        ivec3 lightHash3 = floatBitsToInt(floor(worldPos.xyz+displacementToLight));
        float lightHash = float(((lightHash3.x*53)^(lightHash3.y*17)^(lightHash3.z*97))%255)/255.0;

        color.a+=lightHash;

        vec4 outerBackupB = subgroupShuffle(outerBackupA,goClockwise);
        const float margin = exp2(-8);
        if(abs(visibility.a-blockPosHash)>margin){
            visibility=centerBackupVis;
            if(abs(visibility.a-blockPosHash)>margin){
                if(abs(outerBackupA.a-blockPosHash)<margin)
                    visibility.rgb=outerBackupA.rgb;
                else if(abs(outerBackupB.a-blockPosHash)<margin)
                    visibility.rgb=outerBackupB.rgb;
            }
        }

        if(lightStr>0)
            color.rgb+=colorOfPackedLight(light)*visibility.rgb*lightStr;
    }

    color.a=fract(color.a);
    return color;
}
#endif


vec3 swrtSampleFog(vec3 worldPos){
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


    #define FOG_SWRT_LIGHTS SWRT_LIGHTS_PER_BLOCK
    #define FOG_SWRT_LIGHTS 4
    lightShortList = getLightListLayer(areaPos, 0);
    for(i=0;i<FOG_SWRT_LIGHTS;i++){
        uint light = lightShortList[i&3u];

        if(!bool(light&LIGHT_VALID_BIT))
            break;

        ivec3 lightPosRel = uncheckedUnpackListedLight(light);
        vec3 displacementToLight = lightPosRel-fract(worldPos)+0.5;

        float lightStr = lightFalloff(displacementToLight);

        #if (SWRT_RAYS_PER_FOG_SAMPLE>0) && (defined SWRT_INCLUDE_TRACE)
        if(i<SWRT_RAYS_PER_FOG_SAMPLE)
            if(traceRay(worldPos,displacementToLight)>=0)
                continue;
        #endif

        color+= colorOfPackedLight(light)*lightStr;
    }

    return color;
}