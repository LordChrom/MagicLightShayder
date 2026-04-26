#include "/lib/util/conversions.glsl"

uint nextRand(uint seed){
    seed=seed^(seed>>16);
    seed = (seed<<7)^(seed>>25)^seed;
    seed = (seed<<16) ^ (((seed>>16)^(seed>>21)^(seed>>13)^(~seed>>10)^0xf23fu^seed));
    return seed;
}


float doSsao(vec2 texcoord, vec2 normalDir, float solidDepth, float dither){
    dither = temporalNoise(dither);
    uint rand = uint(0xffffffffu*dither)^0x78949548u;
    float goodSamples = 0;
    float total = 0;
    rand = nextRand(rand);

    solidDepth = depthToLinear(solidDepth);
    float radius = (SSAO_RADIUS*0.3)/solidDepth;
    const float minDirectionality = -0.1;
    for(int i=0; i<SSAO_SAMPLES;i++){
        rand = nextRand(rand);
        vec2 offset = unpackSnorm4x8(rand).zw;
        float d = dot(normalize(offset),normalDir);
        offset = d>=0?offset:-offset;
        float validness = abs(d);

        offset*=abs(offset)*radius;
        float sampledDepth = texelFetch(depthtex2,ivec2((texcoord+offset)*vec2(viewWidth,viewHeight)),0).x;
        sampledDepth=depthToLinear(sampledDepth);

        validness *= clamp((sampledDepth-solidDepth+0.8),0,1);

        goodSamples+=validness;
        if(sampledDepth>=solidDepth)
            total+=validness;

    }
    if(goodSamples==0)
        return 1;
    float ssao = float(total)/float(goodSamples);
    ssao*=ssao;
    const float mult = (SSAO_STRENGTH/(pow(min(SSAO_SAMPLES,8),0.5)));
    ssao=1-(1-ssao)*mult;
    return clamp(ssao,0.3,1);
}