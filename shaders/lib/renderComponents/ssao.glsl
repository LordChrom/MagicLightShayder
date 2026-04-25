uint nextRand(uint seed){
    seed=seed^(seed>>16);
    seed = (seed<<7)^(seed>>25)^seed;
    seed = (seed<<16) ^ (((seed>>16)^(seed>>21)^(seed>>13)^(~seed>>10)^0xf23fu^seed));
    return seed;
}


float doSsao(vec2 texcoord, vec2 normalDir, float solidDepth, float dither){
//    dither = temporalNoise(dither);
    uint rand = uint(0xffffffffu*dither)^0x78949548u;
    rand=rand^uint(0xffffffffu*temporalNoise(texcoord.x+texcoord.y));
    int goodSamples = 0;
    int total = 0;
    for(int i=0; i<SSAO_SAMPLES;i++){
        rand = nextRand(rand);
        vec2 offset = unpackSnorm4x8(rand).zw;
        if(dot(normalize(offset),normalDir)<-0.0)
            offset*=-1;
        offset*=abs(offset);
        offset*=SSAO_RADIUS;
        float sampledDepth = texelFetch(depthtex2,ivec2((texcoord+offset)*scaledScreenDim),0).x;
//        if(solidDepth/sampledDepth>1.005)
//            continue;
        goodSamples++;
        total+=int(sampledDepth>solidDepth);
    }
    float ssao = float(total)/float(goodSamples);
    ssao*=ssao;
    ssao=1-(1-ssao)*SSAO_STRENGTH;
    return clamp(ssao,0.3,1);
}