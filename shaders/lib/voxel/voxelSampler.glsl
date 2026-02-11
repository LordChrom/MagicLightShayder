
layout (rgba32f) uniform readonly restrict image3D lightVox;
layout (rgba8ui) uniform readonly restrict uimage3D worldVox;

#include "/lib/voxel/voxelHelper.glsl"

vec3 voxelSample(vec3 worldPos, vec3 normal){
    worldPos+=normal*0.01;
    ivec3 sectionPos = worldPosToSection(worldPos);
    vec4 lightMeta = imageLoad(lightVox, sectionPos);

    float lightStrength = float(floatBitsToUint(lightMeta.a)&0xfu)/15.0;

    float mult = 0.1;
    vec3 displacement = lightMeta.xyz-worldPos;
    float lengthSquared = displacement.x*displacement.x+displacement.y*displacement.y+displacement.z*displacement.z;

    mult+=lightStrength/lengthSquared;
    return vec3(mult);
}