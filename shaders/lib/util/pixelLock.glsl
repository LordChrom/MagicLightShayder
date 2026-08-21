#ifndef PIXEL_LOCK_GLSL
#define PIXEL_LOCK_GLSL
vec3 pixelLock(vec3 worldPos, float pixelSize){
    vec3 pixel = worldPos/pixelSize;
    float middleZone = pixelSize/8.0;
    return (0.5*(floor(pixel-middleZone)+floor(pixel+middleZone))+0.5)*pixelSize;
}
#endif