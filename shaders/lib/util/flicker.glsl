uniform int frameCounter;

uniform ivec3 currentTime;
uniform float frameTimeCounter;

float currentTimeSec(){
    return frameTimeCounter;
}

float flicker(){
    float time = currentTimeSec();
    return 1+clamp(0.2*sin(time*3)+0.2*sin(time*10)+0.05*sin(time*47),-0.5,0);
}

float pulsate(){
    float time = currentTimeSec();
    return 0.85+0.15*sin(time*3);
}