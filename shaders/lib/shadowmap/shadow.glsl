uniform mat4 shadowModelView, shadowProjection;
#ifdef GBUFFER_SHADER
uniform mat4 gbufferModelViewInverse;
#endif
uniform sampler2DShadow shadowtex0;
uniform vec3 shadowLightPosition;
//uniform vec3 cameraPosition;
#include "/lib/shadowmap/distortion.glsl"
//#include "/lib/util/misc.glsl"


const bool shadowHardwareFiltering = true;

const vec3 sunColor = vec3(232.0/255.0);
const vec3 moonColor = vec3(0.22,0.22,0.48);
vec3 shadowmapSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue){
    worldPos-=cameraPosition;
    vec3 lightSrcPosRel = (gbufferModelViewInverse*vec4(shadowLightPosition,1)).xyz;
    lightSrcPosRel-=worldPos;
    float nol = dot(normalize(lightSrcPosRel),normal);

    worldPos+=clamp(0.01*length(worldPos),1e-2,0.8)*normal;

    vec4 shadowPos = vec4(mat3(shadowModelView)*worldPos+shadowModelView[3].xyz,1);
    shadowPos = shadowProjection*shadowPos;
    shadowPos.z-=0.0005;
    shadowPos.xyz=distort(shadowPos.xyz);
    shadowPos.xyz/=shadowPos.w;
    shadowPos.xyz=shadowPos.xyz*0.5+0.5;
    float strength = clamp(nol*texture(shadowtex0,shadowPos.xyz),0,1)*0.8+0.2;
    return strength*(sunAngle>0.5?moonColor:sunColor);
}


vec3 shadowmapSampleFog(vec3 worldPos, float fogNoise, float ditherValue){
    if(sunAngle>0.5)
        return vec3(0.1);
    worldPos-=cameraPosition;
    vec4 shadowPos = vec4(mat3(shadowModelView)*worldPos+shadowModelView[3].xyz,1);
    shadowPos = shadowProjection*shadowPos;
    shadowPos.xyz=distort(shadowPos.xyz);
    shadowPos.xyz/=shadowPos.w;
    shadowPos.xyz=shadowPos.xyz*0.5+0.5;
    float strength = FOG_BRIGHTNESS_SUN*texture(shadowtex0,shadowPos.xyz);
    return strength*(sunAngle>0.5?moonColor:sunColor);
}