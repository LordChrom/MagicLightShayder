#ifdef TAA

//from -0.5 to 0.5
vec2 jitter2(int entropy){
    return vec2(ivec2(entropy,entropy>>1)&1)-0.5;
}

vec2 jitter(){
    vec2 jitter = vec2(0);

    #if TAA_JITTER_INTERVAL >= 4
    jitter  = 0.5*jitter2(frameCounter);
    #endif
    #if TAA_JITTER_INTERVAL >= 16
    jitter += 0.25*jitter2(frameCounter^(frameCounter>>2));
    #endif
    #if TAA_JITTER_INTERVAL >= 64
    jitter += 0.125*jitter2(frameCounter^(frameCounter>>4));
    #endif
    #if TAA_JITTER_INTERVAL >= 128
    jitter += 0.0625*jitter2(frameCounter^(frameCounter>>6));
    #endif

    #if DEBUG_SPECIAL_VIEW == 200
    float timer = fract(frameCounter*0.01);
    timer = timer<0.5?2*timer:2-2*timer;
    jitter=vec2(timer);
    #endif
    return jitter/scaledScreenDim;
}
#endif