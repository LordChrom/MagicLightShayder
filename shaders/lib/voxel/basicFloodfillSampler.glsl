#define SAMPLES_FLOOD
#include "/lib/voxel/voxelHelper.glsl"
#ifndef GBUFFER_SHADER

uniform sampler2D lightmap;
#endif

vec3 sampleFloodfillLight(vec3 worldPos, vec3 normal){
    vec4 sampleLight = sampleFloodData(worldPos+0.01*normal);
    vec4 sunlight = texture(lightmap,clamp(vec2(0,sampleLight.a),1.0/32.0,31.0/32.0));
    return sampleLight.rgb*2;
}

vec3 sampleFloodfillFog(vec3 worldPos){
    vec4 sampleLight = sampleFloodData(worldPos);
    sampleLight.rgb*=FOG_BRIGHTNESS_BLOCK;
    vec4 sunlight = texture(lightmap,clamp(vec2(0,sampleLight.a),1.0/32.0,31.0/32.0));
    sampleLight.rgb+=FOG_BRIGHTNESS_SUN*sunlight.rgb;

    return sampleLight.rgb;
}
