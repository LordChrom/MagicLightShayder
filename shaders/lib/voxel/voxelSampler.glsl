
layout (rgba32ui) uniform readonly restrict uimage3D lightVox;
layout (rgba8ui) uniform readonly restrict uimage3D worldVox;

#include "/lib/voxel/voxelHelper.glsl"

vec3 voxelSample(vec3 worldPos, vec3 normal){
    worldPos+=vec3(0,0,-0.099); //TODO figure this out, probably something stupid

    worldPos+=normal*0.001;
    ivec3 sectionPos = worldPosToSection(worldPos,1);
    lightVoxData lightSrc = unpackLightData(imageLoad(lightVox, sectionPos));

    float lightStrength = lightSrc.emissive/15.0;

    vec3 displacement = lightSrc.lightTravel + subVoxelOffset(worldPos,1);

    float lengthSquared = dot(displacement,displacement);

    lightStrength/=max(lengthSquared,0.01);

    uvec4 testSlopes = lightSrc.slopes;
    bool receivesLight = isAdjustedPointInSlopes(displacement, testSlopes);


    float lightDotN = -dot(displacement,normal);

    receivesLight = receivesLight && lightDotN>=0 && lightSrc.emissive>0;



    if(receivesLight){
        lightStrength=max(lightStrength,0.2);
    }else{
        lightStrength*=0.2;
    }
    float mult = 0.1+lightStrength;

    return vec3(mult);
}