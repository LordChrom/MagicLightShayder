//#define WORLD_TIME

//TODO find a way that advances proportionally to game ticks regardless of world time

#ifdef WORLD_TIME
uniform int worldTime;
float currentTimeSec(){
    return worldTime*0.05;
}
#else
uniform float frameTimeCounter;

float currentTimeSec(){
    return frameTimeCounter;
}
#endif


float loopingAnimation(float speed){
    return fract(currentTimeSec()*speed);
}
