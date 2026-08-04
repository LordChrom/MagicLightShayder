#ifdef TAA
#include "/lib/util/taaJitter.glsl"

float lightSampleWeight(vec2 jitteredTexpos){
#if !(LIGHTING_RENDERSCALE == 1)
    vec2 diffPx = abs(jitteredTexpos*scaledScreenDim-round(jitteredTexpos*scaledScreenDim+0.5)+0.5);
    float spatialFactor =(diffPx.x+diffPx.y);
    spatialFactor *= (TAA_SPATIALITY*(1.2-LIGHTING_RENDERSCALE));
//    spatialFactor -= 10*(TAA_SPATIALITY*TAA_MOTION_REJECTION)*length(cameraPosition-previousCameraPosition);
//    spatialFactor /= max(1,TAA_MOTION_REJECTION*length(cameraPosition-previousCameraPosition));
    float weight = clamp(1-spatialFactor,0,1);
    weight*=weight;
    return clamp(weight,TAA_MIN_ACCUMULATION_RATE,TAA_MAX_ACCUMULATION_RATE);
#else
    const float rate = (TAA_MAX_ACCUMULATION_RATE+TAA_MIN_ACCUMULATION_RATE)*0.5;
    return rate;
#endif
}

float fogSampleWeight(vec2 jitteredTexpos){
#if !(LIGHTING_RENDERSCALE == 1)
    vec2 diffPx = abs(jitteredTexpos*scaledScreenDim-round(jitteredTexpos*scaledScreenDim+0.5)+0.5);
    float spatialFactor =(diffPx.x+diffPx.y);
    spatialFactor *= (TAA_FOG_FACTOR*TAA_SPATIALITY*(1.2-LIGHTING_RENDERSCALE));
    spatialFactor -= (TAA_SPATIALITY*TAA_MOTION_REJECTION*0.1/TAA_FOG_FACTOR)*length(cameraPosition-previousCameraPosition);
//    spatialFactor /= max(1,TAA_MOTION_REJECTION*length(cameraPosition-previousCameraPosition));

    float weight = clamp(1-spatialFactor,0,1);
    weight*=weight;

    return clamp(weight,0,TAA_MAX_ACCUMULATION_RATE);
#else
    const float rate = TAA_FOG_FACTOR*(TAA_MAX_ACCUMULATION_RATE+TAA_MIN_ACCUMULATION_RATE)*0.5;
    return rate;
#endif
}

vec3 toWorldPos(vec3 screenPos){
    vec3 ndcPos = screenPos*2-1;

    vec4 viewPos = gbufferProjectionInverse*vec4(ndcPos,1);
    viewPos/=viewPos.w;
    vec3 feetPos = (gbufferModelViewInverse*viewPos).xyz;

    return feetPos + cameraPosition;
}

vec3 reproject(vec3 screenPos){
    vec4 tmp;
    tmp.xyz = toWorldPos(screenPos)-previousCameraPosition;
    tmp.xyz = (gbufferPreviousModelView*vec4(tmp.xyz,1.0)).xyz;
    tmp = gbufferPreviousProjection*vec4(tmp.xyz,1.0);
    tmp.xyz/=tmp.w;
    return tmp.xyz*0.5+0.5;
}
#endif