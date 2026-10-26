const float rippleWrap = 128.0;

const uint rippleCount = 16;
//initially from random.org there, then tweaked manually.
//TODO make these change over time
const uint[] rippleList = {
    0000000000u, 0xd97a0740u, 0x16f21f6eu, 0x9a272240u,
    0x690f3323u, 0xc1a44655u, 0x8be1500eu, 0x3fc76ef1u,
    0xfa8b74ecu, 0xd94f8c9cu, 0xb04e9590u, 0x6605a27au,
    0x31b7b1f6u, 0x6bc2c559u, 0xbd94ef6cu, 0x77c9d51fu,
};


vec2 wrapRippleCoord(vec2 pos){
    return (fract(pos/rippleWrap+0.5)-0.5)*rippleWrap;
}

float calcWaveHeight(vec2 posFromCenter){
    float waveX = length(posFromCenter);
    return WATER_WAVE_HEIGHT*sin(WATER_WAVE_PEAKS_PER_BLOCK*waveX-WATER_WAVE_SPEED*frameTimeCounter)*exp(waveX*-0.1);
}

vec2 calcWaveDerivative(vec2 posFromCenter){
    float waveX = length(posFromCenter);
    return -(WATER_WAVE_HEIGHT*WATER_WAVE_PEAKS_PER_BLOCK)*cos(WATER_WAVE_PEAKS_PER_BLOCK*waveX-WATER_WAVE_SPEED*frameTimeCounter)*normalize(posFromCenter)*exp(waveX*-0.1);
}

vec2 getRippleInfo(uint ripple){
    return unpackUnorm2x16(ripple)*rippleWrap;
}


vec3 calcWavesNormal(vec2 posFromCenter){
    posFromCenter=wrapRippleCoord(posFromCenter);
    vec2 waveDerivative = vec2(0);
    for(uint i=0;i<rippleCount;i++){
        vec2 ripple = getRippleInfo(rippleList[i]);
        ripple = wrapRippleCoord(posFromCenter-ripple);
        waveDerivative+=calcWaveDerivative(ripple);
    }
    return normalize(vec3(waveDerivative.x,1f,waveDerivative.y));
}


float calcWavesHeight(vec2 posFromCenter){
    posFromCenter=wrapRippleCoord(posFromCenter);
    #ifdef DEBUG_WATER_RIPPLES
    if(min(abs(posFromCenter.x),abs(posFromCenter.y))<0.3) return 1;
    #endif

    float height = 0f;
    for(uint i=0;i<rippleCount;i++){
        vec2 ripple = getRippleInfo(rippleList[i]);
        ripple = wrapRippleCoord(posFromCenter-ripple);
        height+=calcWaveHeight(ripple);
    }
    return height;
}
