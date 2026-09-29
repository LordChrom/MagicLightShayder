#ifndef SHADOW_LIGHT_INFO_GLSL
#define SHADOW_LIGHT_INFO_GLSL
uniform vec3 shadowLightPosition;
uniform int biome_category;

uniform float sunAngle;
uniform bool hasCeiling;
//uniform bool hasSkylight;

const vec3 sunColor = vec3(240.0/255.0);
const vec3 moonColor = vec3(0.22,0.22,0.48);

vec3 getSunColor(){
    if(hasCeiling) return vec3(0);
    if(biome_category==CAT_THE_END)
        return vec3(0.55,0.61,0.55);
    return (sunAngle>0.5?moonColor:sunColor);
}

vec3 getSunColorForFog(){
    vec3 ret = getSunColor();
    if(biome_category==CAT_THE_END)
        ret*=0.1;
    return ret;
}
#endif