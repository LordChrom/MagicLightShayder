#include "/lib/util/conversions.glsl"

uint nextRand(uint value, uint seed){
    value ^= value<<17;
    value ^= value>>11;
    value ^= seed ^ (seed>>5);
    return value+seed;
}


float doSsao(vec2 texcoord, vec2 normalDir, float solidDepth, float dither){
    dither = temporalNoise(dither);
    uint seed = floatBitsToUint(dither) ^ (floatBitsToUint(dither + solidDepth)>>3);
    seed ^= bitfieldReverse(seed);
    uint rand = nextRand(seed,seed);

    float goodSamples = 0;
    float total = 0;

    solidDepth = depthToLinear(solidDepth);
    float radius = (SSAO_RADIUS*0.3)/solidDepth;
    radius = min(radius,0.15);

    for(int i=0; i<SSAO_SAMPLES;i++){
        rand = nextRand(rand,seed);
        vec4 offset4 = unpackUnorm4x8(rand^(rand<<16));
        vec2 offset = (offset4.xy-offset4.zw);
        float len = length(offset);
        if(len>1)
            offset=offset*fract(len)/len;

        float d = dot(normalize(offset),normalDir);
        offset = d>-0?offset:-offset;
        float validness = abs(d);

        offset*=abs(offset)*radius;
        offset+=texcoord;
        if(offset.x>1.0 || offset.y>1.0 || offset.x<0 || offset.y<0)
            continue;
        float sampledDepth = texture(depthtex2,offset).x;
        sampledDepth=depthToLinear(sampledDepth);

        validness *= clamp((sampledDepth-solidDepth+0.8),0,1);

        goodSamples+=validness;
        if(sampledDepth>=solidDepth)
            total+=validness;

    }
    if(goodSamples==0)
        return 0.5;
    float ssao = float(total)/float(goodSamples);
    ssao*=ssao;
    const float mult = (SSAO_STRENGTH/(pow(min(SSAO_SAMPLES,8),0.5)));
    ssao=1-(1-ssao)*mult;
    return clamp(ssao,0.3,1);
}