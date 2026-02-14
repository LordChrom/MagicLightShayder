
layout (rgba32ui) uniform readonly restrict uimage3D lightVox;
layout (rgba8ui) uniform readonly restrict uimage3D worldVox;

#include "/lib/voxel/voxelHelper.glsl"

vec3 voxelSample(vec3 worldPos, vec3 normal){
    worldPos+=vec3(0,0,-0.1); //TODO figure this out, probably something stupid

    worldPos+=normal*0.001;
    ivec3 sectionPos = worldPosToSection(worldPos,1);
    lightVoxData lightSrc = unpackLightData(imageLoad(lightVox, sectionPos));

    float lightStrength = lightSrc.emission/15.0;

    vec3 displacement = lightSrc.lightTravel + subVoxelOffset(worldPos,1);

    lightStrength*=step(0,displacement.z);

    float lengthSquared = dot(displacement,displacement);

    lightStrength/=max(lengthSquared,0.01);


    float lightDotN = -dot(displacement,normal);

    bool receivesLight = lightDotN>=0 && lightSrc.emission>0;


    vec3 outColor = vec3(0.1);

    if(receivesLight){
        lightStrength=max(lightStrength,0.03); //mostly just for testing
        outColor += lightSrc.color*(0.1+0.9*min(lightStrength,1));
    }

    return outColor;
}