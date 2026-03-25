float bayer2(ivec2 pos){
    return 0.25*((2*(pos.x&1)-(pos.y&1))&3);
}

float bayer4(ivec2 pos){
    return bayer2(pos) + 0.25*bayer2(pos>>1);
}

float bayer8(ivec2 pos){
    return bayer4(pos) + 0.0625*bayer4(pos>>2);
}

float bayer16(ivec2 pos){
    return bayer8(pos) + 0.015625*bayer4(pos>>3);
}

float dither(ivec2 pos){
#if FOG_DITHER_METHOD == 16
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