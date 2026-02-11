
layout (rgba16f) uniform readonly restrict image3D lightVox;
layout (rgba8ui) uniform readonly restrict uimage3D worldVox;

#include "/lib/voxel/voxelHelper.glsl"

vec3 voxelSample(vec3 worldPos, vec3 normal){
    vec4 imageData = imageLoad(lightVox, ivec3(floor(worldPos))+ivec3(0));
    ivec3 lightWorldPos = ivec3(floor(worldPos+imageData.xyz));
    uvec4 lightSource = imageLoad(worldVox, lightWorldPos);
    float lightStrength = (lightSource.a>>4u)/15.0;
    float mult = 0.1;
//    mult += imageData.a*0.5;
    float dist = length(max(abs(lightWorldPos+vec3(0.5,0.5,0)-worldPos),vec3(0.5,0.5,0)));
    mult+=lightStrength/(dist*dist);
    return vec3(mult);
}