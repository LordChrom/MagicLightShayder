#ifndef CONVERSIONS_GLSL
#define CONVERSIONS_GLSL
uniform vec2 depthConvConsts;

//uniform mat4 gbufferProjectionInverse;
float depthToLinear(float sampleDepth){
    sampleDepth = fma(sampleDepth,2.0,-1.0);

    return  1.0/fma(sampleDepth,depthConvConsts.y,depthConvConsts.x);
}

float depthToBuf(float worldDepth){
        float sampleDepth =  (1.0/worldDepth-depthConvConsts.x)/depthConvConsts.y;
    return fma(sampleDepth,0.5,0.5);
}

vec2 depthsToBuf(vec2 worldDepth){
    vec2 sampleDepth =  (1.0/worldDepth-depthConvConsts.x)/depthConvConsts.y;
    return sampleDepth*0.5+0.5;
}
#endif