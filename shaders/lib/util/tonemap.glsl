const float stretch = 8;
const float topCutoff = 0.7;

vec3 superbasicTonemap(vec3 color){
    vec3 which = vec3(color.x>topCutoff,color.y>topCutoff,color.z>topCutoff);
    vec3 mappedDown = topCutoff+log(1+stretch*(color-topCutoff))/stretch;

    return max(which*mappedDown,0.0)+(1-which)*color;
}
const float center = 0.4;
const float k = 1.6f;

//equivalent to logistic function of log(x)
vec3 logisticTonemap(vec3 color){
    return 1f/(1f+pow(center/color,vec3(k)));
}

vec3 tonemap(vec3 color){
#if TONEMAP_METHOD == 0
    return superbasicTonemap(color);
#elif TONEMAP_METHOD == 1
    return logisticTonemap(color);
#else
    return color;
#endif
}