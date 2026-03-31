const float stretch = 8;
const float topCutoff = 0.7;

vec3 superbasicTonemap(vec3 color){
    vec3 which = vec3(color.x>topCutoff,color.y>topCutoff,color.z>topCutoff);
    vec3 mappedDown = topCutoff+log(1+stretch*(color-topCutoff))/stretch;

    return which*mappedDown+(1-which)*color;
}

vec3 tonemap(vec3 color){
#if TONEMAP_METHOD == 0
    return superbasicTonemap(color);
#else
    return color;
#endif
}