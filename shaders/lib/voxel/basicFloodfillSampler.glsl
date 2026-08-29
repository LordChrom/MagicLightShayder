#define SAMPLES_FLOOD
#include "/lib/voxel/voxelHelper.glsl"
uniform sampler2D lightmapTex;

vec3 getFloodfillSunlight(float sunlightness){
    return texture(lightmapTex,clamp(vec2(0,sunlightness),1.0/32.0,31.0/32.0)).rgb;
}

vec3 sampleFloodfillLight(vec3 worldPos, vec3 normal){
    vec4 sampleLight = sampleFloodData(worldPos+0.01*normal);
    sampleLight.rgb+=getFloodfillSunlight(sampleLight.a);
    return sampleLight.rgb;
}

vec3 sampleFloodfillFog(vec3 worldPos){
    vec4 sampleLight = sampleFloodData(worldPos);
    sampleLight.rgb*=FOG_BRIGHTNESS_BLOCK;
    sampleLight.rgb+=getFloodfillSunlight(sampleLight.a)*FOG_BRIGHTNESS_SUN;

    return sampleLight.rgb;
}
