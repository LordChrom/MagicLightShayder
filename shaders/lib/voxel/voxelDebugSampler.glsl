vec4 voxelSample(vec3 worldPos, vec3 normal){
    return imageLoad(lightVox, ivec3(floor(worldPos))+ivec3(1));
}