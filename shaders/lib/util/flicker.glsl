#include "/lib/util/time.glsl"


//this noise probably sucks but oh well.
float blockPosNoise(ivec3 pos){
    uint tmp = (pos.x*7)^(pos.y*3)^(pos.z*5);
    return 10*(((tmp.x&0xf0u)>>4)+(((tmp.x&0xfu)<<4)));
//    return pos.y*3.7+((pos.x*3)+pos.z*13);
}


float flicker(float offset){
    float time = offset+currentTimeSec();
    return 1+FLICKER_INTENSITY*clamp(0.4*sin(time*3)+0.4*sin(time*10)+0.1*sin(time*47),-1,0);
}
float flicker(){return flicker(0);}
float flicker(ivec3 blockPos){return flicker(0.1*blockPosNoise(blockPos));}

float pulsate(){
    float time = currentTimeSec();
    return 0.85+0.15*sin(time*3);
}