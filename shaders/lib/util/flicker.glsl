#include "/lib/util/time.glsl"


//this noise probably sucks but oh well.
float blockPosNoise(ivec3 pos){
    uint tmp = (pos.x*7)^(pos.y*3)^(pos.z*5);
    tmp = (tmp>>8)^(tmp<<8);
    tmp = (tmp>>4)^(tmp<<4);
    return (tmp>>12)&0xffu;
}


float flicker(float offset){
    float time = offset+currentTimeSec();
    return 1+FLICKER_INTENSITY*clamp(0.4*(sin(time*3)+sin(time*10))+0.1*sin(time*47),-1,0);
}
float flicker(){return flicker(0);}
float flicker(ivec3 blockPos){return flicker(blockPosNoise(blockPos));}

float pulsate(){
    float time = currentTimeSec();
    return 0.85+0.15*sin(time);
}