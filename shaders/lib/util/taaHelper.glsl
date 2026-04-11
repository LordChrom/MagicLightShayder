//from -0.5 to 0.5
vec2 jitter2(int entropy){
    return vec2(ivec2(entropy,entropy>>1)&1)-0.5;
}

vec2 jitter(){
#if TAA_JITTER_INTERVAL == 4
    vec2 jitter=0.5*jitter2(frameCounter);
#elif TAA_JITTER_INTERVAL == 16
    vec2 jitter=0.5*jitter2(frameCounter)+0.25*jitter2(-(frameCounter>>2));
#elif TAA_JITTER_INTERVAL == 64
    vec2 jitter=0.5*jitter2(frameCounter)+0.25*jitter2(-(frameCounter>>2))+ 0.125*jitter2(frameCounter>>4);
#else
    vec2 jitter = vec2(0);
#endif

#if DEBUG_SPECIAL_VIEW == 200
    float timer = fract(frameCounter*0.01);
    timer = timer<0.5?2*timer:2-2*timer;
    jitter=vec2(timer);
#endif
    return jitter/scaledScreenDim;
}

float lightSampleWeight(vec2 jitteredTexpos){
    vec2 diffPx = abs(jitteredTexpos*scaledScreenDim-round(jitteredTexpos*scaledScreenDim+0.5)+0.5);
    float spatialFactor =(diffPx.x+diffPx.y);
    spatialFactor *= (TAA_SPATIALITY*(1.2-LIGHTING_RENDERSCALE));
    spatialFactor -= (TAA_SPATIALITY*TAA_MOTION_REJECTION)*length(cameraPosition-previousCameraPosition);

#if LIGHTING_RENDERSCALE == 1
    spatialFactor=0;
#endif
    float weight = clamp(1-spatialFactor,0,1);
    weight*=weight;

    return clamp(weight,TAA_MIN_ACCUMULATION_RATE,TAA_MAX_ACCUMULATION_RATE);
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