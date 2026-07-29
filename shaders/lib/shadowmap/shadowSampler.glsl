uniform mat4 shadowModelView, shadowProjection;
#ifdef GBUFFER_SHADER
uniform mat4 gbufferModelViewInverse;
#endif

uniform sampler2D shadowtex0;
uniform vec3 shadowLightPosition;
uniform vec2 shadowDepthConvConsts;

//uniform vec3 cameraPosition;
#include "/lib/shadowmap/distortion.glsl"
//#include "/lib/util/misc.glsl"


const vec3 sunColor = vec3(240.0/255.0);
const vec3 moonColor = vec3(0.22,0.22,0.48);

//#define SHADOW_SAMPLING_ANGULAR
float shadowSample(vec3 shadowpos){
    if(shadowpos.x<0)
        return 1;
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
uniform mat4 shadowProjectionInverse;

float shadowDepthToLinear(float sampleDepth){
    sampleDepth*=2-1;
    sampleDepth*=2;
    return (shadowDepthConvConsts.x*sampleDepth+shadowDepthConvConsts.y);///(shadowProjectionInverse[3].z*sampleDepth+shadowProjectionInverse[3].w);
}

vec3 worldSpaceToShadow(vec3 worldPos){
    vec4 shadowPos = vec4(mat3(shadowModelView)*worldPos+shadowModelView[3].xyz,1);
    shadowPos = shadowProjection*shadowPos;
    shadowPos.xyz=distort(shadowPos.xyz);
    shadowPos.xyz/=shadowPos.w;
    shadowPos.xyz=shadowPos.xyz*0.5+0.5;
    return shadowPos.xyz;
}

vec3 worldSpaceToShadowSunBiased(vec3 worldPos){
    vec4 shadowPos = vec4(mat3(shadowModelView)*worldPos+shadowModelView[3].xyz,1);
    shadowPos = shadowProjection*shadowPos;
    shadowPos.z-=0.0005;
    shadowPos.xyz=distort(shadowPos.xyz);
    shadowPos.xyz/=shadowPos.w;
    shadowPos.xyz=shadowPos.xyz*0.5+0.5;
    return shadowPos.xyz;
}



vec3 shadowmapSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue){
    worldPos-=cameraPosition;
    vec3 lightSrcPosRel = (gbufferModelViewInverse*vec4(shadowLightPosition,1)).xyz;
    lightSrcPosRel-=worldPos;
    float nol = dot(normalize(lightSrcPosRel),normal);
    float worldPosLen = length(worldPos)*0.01;
    vec3 shadowPos = worldSpaceToShadowSunBiased(worldPos+clamp(worldPosLen,1e-1,0.8)*normal);
    float sampl = shadowSample(shadowPos);
    float strength = clamp(nol*sampl,0,1)*0.8+0.2;
    #if SUBSURFACE_MODE==2 && defined SUN_SHADOW_SUBSURFACE
    if(subsurface>0)
    {
        shadowPos = worldSpaceToShadow(worldPos-clamp(mix(nol*-0.5+0.1,0.5,max(0,worldPosLen-0.1)),0,1)*normal);
//        shadowPos = worldSpaceToShadow(worldPos);
        float sunHitDepth = shadowDepthToLinear(texture(shadowtex0,shadowPos.xy).x);
        float actualHitDepth = shadowDepthToLinear(shadowPos.z);
        float subSurfaceDepth = max(0,(sunHitDepth-actualHitDepth))*1.79+0.01;
//        return vec3(fract(subSurfaceDepth));
        subSurfaceDepth = min(-0.15,-3*subSurfaceDepth);

        float subsurfaceStrength = 0.66*exp(subSurfaceDepth/max(0.01,subsurface));
        subsurfaceStrength=max(0,subsurfaceStrength);
        strength=sqrt(strength*strength+subsurfaceStrength*subsurfaceStrength);
    }
    #endif
    return (strength)*(sunAngle>0.5?moonColor:sunColor);
}

vec3 shadowmapSampleFog(vec3 worldPos, float ditherValue){
    if(sunAngle>0.5)
        return vec3(0.1);
    worldPos-=cameraPosition;
    vec3 shadowPos =  worldSpaceToShadow(worldPos);
    float strength = FOG_BRIGHTNESS_SUN*shadowSample(shadowPos);
    return strength*(sunAngle>0.5?moonColor:sunColor);
}