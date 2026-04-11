uniform vec2 scaledScreenDim;

//from -0.5 to 0.5
vec2 jitter2(int entropy){
    return vec2(ivec2(entropy,entropy>>1)&1)-0.5;
}

vec2 jitter(){
#if TAA_JITTER_INTERVAL == 4
    vec2 jitter=0.5*jitter2(frameCounter);
#elif TAA_JITTER_INTERVAL == 16
    vec2 jitter=0.5*jitter2(frameCounter)+0.25*jitter2(-(frameCounter>>2));
#else
    return vec2(0);
#endif
    return jitter/scaledScreenDim;
}

float lightSampleWeight(vec2 jitteredTexpos){
    vec2 diffPx = abs(jitteredTexpos*scaledScreenDim-round(jitteredTexpos*scaledScreenDim+0.5)+0.5);
    float weight = clamp(1.0-diffPx.x-diffPx.y,0,1);
    return weight;
}
