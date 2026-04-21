uint bayer2u(ivec2 pos){
    return ((pos.x&1)<<31)-((pos.y&1)<<30);
}

uint bayer4u  (ivec2 pos){ return bayer2u(pos)  + (bayer2u(pos>>1)>>2 ); }
uint bayer8u  (ivec2 pos){ return bayer4u(pos)  + (bayer2u(pos>>2)>>4 ); }
uint bayer16u (ivec2 pos){ return bayer8u(pos)  + (bayer2u(pos>>3)>>6 ); }
uint bayer32u (ivec2 pos){ return bayer16u(pos) + (bayer2u(pos>>4)>>8 ); }
uint bayer64u (ivec2 pos){ return bayer32u(pos) + (bayer2u(pos>>5)>>10); }
uint bayer128u(ivec2 pos){ return bayer64u(pos) + (bayer2u(pos>>6)>>12); }

const float floatAndShift = pow(2,-32);
float bayer2  (ivec2 pos){return floatAndShift*bayer2u(pos);  }
float bayer4  (ivec2 pos){return floatAndShift*bayer4u(pos);  }
float bayer8  (ivec2 pos){return floatAndShift*bayer8u(pos);  }
float bayer16 (ivec2 pos){return floatAndShift*bayer16u(pos); }
float bayer32 (ivec2 pos){return floatAndShift*bayer32u(pos); }
float bayer64 (ivec2 pos){return floatAndShift*bayer64u(pos); }
float bayer128(ivec2 pos){return floatAndShift*bayer128u(pos);}


float dither(ivec2 pos){
#if FOG_DITHER_METHOD == 128
    return bayer128(pos);
#elif FOG_DITHER_METHOD == 64
    return bayer64(pos);
#elif FOG_DITHER_METHOD == 32
    return bayer32(pos);
#elif FOG_DITHER_METHOD == 16
    return bayer16(pos);
#elif FOG_DITHER_METHOD == 8
    return bayer8(pos);
#elif FOG_DITHER_METHOD == 4
    return bayer4(pos);
#elif FOG_DITHER_METHOD == 2
    return bayer2(pos);
#else
    return 0.5;
#endif
}

float temporalNoise(float x){
    const uint temporalLoop = 256;
    const uint temporalMult = 203;
    uint fc = frameCounter;
    return fract((bool(fc&1u)?x:-x) + float(((fc>>1)*temporalMult)&(temporalLoop-1))/temporalLoop);
}