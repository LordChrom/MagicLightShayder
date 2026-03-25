float bayer2(ivec2 pos){
    return 0.25*((2*(pos.x&1)-(pos.y&1))&3);
}

float bayer4(ivec2 pos){
    return bayer2(pos)+0.25*bayer2(pos>>1);
}

float bayer8(ivec2 pos){
    return bayer4(pos) + 0.0625*bayer4(pos>>2);
}

float dither(ivec2 pos){
#if DITHER_METHOD == 8
    return bayer8(pos);
#elif DITHER_METHOD == 4
    return bayer4(pos);
#elif DITHER_METHOD == 2
    return bayer2(pos);
#else
    return 0.5;
#endif
}