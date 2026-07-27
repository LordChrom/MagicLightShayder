uniform mat4 shadowModelView, shadowProjection;
#ifdef GBUFFER_SHADER
uniform mat4 gbufferModelViewInverse;
#endif

uniform sampler2D shadowtex0;
uniform vec3 shadowLightPosition;
//uniform vec3 cameraPosition;
#include "/lib/shadowmap/distortion.glsl"
//#include "/lib/util/misc.glsl"


const vec3 sunColor = vec3(232.0/255.0);
const vec3 moonColor = vec3(0.22,0.22,0.48);

//#define SHADOW_SAMPLING_ANGULAR
float shadowSample(vec3 shadowpos){
    vec4 depths = textureGather(shadowtex0,shadowpos.xy,0); //BL BR TR TL
    //TL TR BL BR
    ivec4 visibilities = ivec4(depths.w>=shadowpos.z,depths.z>=shadowpos.z,depths.x>=shadowpos.z,depths.y>=shadowpos.z);
    vec2 mix2d = fract(shadowpos.xy*textureSize(shadowtex0,0));
    #ifdef SHADOW_SAMPLING_ANGULAR
    mix2d = fract(mix2d+0.5)-0.5;
    float retVal= visibilities[(mix2d.y>0?2:0)+(mix2d.x>0?1:0)];

    if(abs(mix2d.x)+abs(mix2d.y)<0.5){
        retVal=clamp(visibilities.x+visibilities.y+visibilities.z+visibilities.w-2,-1,1);
        if(abs(visibilities.x+visibilities.z-visibilities.y-visibilities.w)>1.5)
            retVal = mix2d.x<0?visibilities.x:visibilities.y;

        if(abs(visibilities.x+visibilities.y-visibilities.z-visibilities.w)>1.5)
            retVal = mix2d.y<0?visibilities.x:visibilities.z;
    }

    return retVal;
    #else
    mix2d-=0.5;
    mix2d = fract(mix2d*sqrt(sqrt(abs(mix2d))));
    vec2 UD = mix(visibilities.xy,visibilities.zw,mix2d.y);
    return mix(UD.x,UD.y,mix2d.x);
    #endif
}
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
    float strength = clamp(nol*shadowSample(shadowPos.xyz),0,1)*0.8+0.2;
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
    float strength = FOG_BRIGHTNESS_SUN*shadowSample(shadowPos.xyz);
    return strength*(sunAngle>0.5?moonColor:sunColor);
}