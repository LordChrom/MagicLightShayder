#ifndef SHADOW_LIGHT_INFO_GLSL
#define SHADOW_LIGHT_INFO_GLSL
uniform vec3 shadowLightPosition;
uniform float sunAngle;
uniform bool hasCeiling;

const vec3 sunColor = vec3(240.0/255.0);
const vec3 moonColor = vec3(0.22,0.22,0.48);

vec3 getSunColor(){
    if(hasCeiling) return vec3(0);
    return (sunAngle>0.5?moonColor:sunColor);
}
#endif