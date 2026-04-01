vec3 pixelLock(vec3 worldPos, float pixelSize){
    return (floor(worldPos/pixelSize)+0.5)*pixelSize;
}