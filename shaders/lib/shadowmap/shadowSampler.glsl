uniform mat4 shadowModelView, shadowProjection;
#ifdef GBUFFER_SHADER
uniform mat4 gbufferModelViewInverse;
#endif

uniform sampler2D shadowcolor0;
uniform vec3 shadowLightPosition;
uniform vec2 shadowDepthConvConsts;

//uniform vec3 cameraPosition;
#include "/lib/shadowmap/distortion.glsl"
#include "/lib/util/pixelLock.glsl"


const vec3 sunColor = vec3(240.0/255.0);
const vec3 moonColor = vec3(0.22,0.22,0.48);



float getShadowDepth(vec2 shadowPos){
    return texture(shadowcolor0,shadowPos.xy).x;
}

const float oneShadowPixel = 1.0/SHADOW_RESOLUTION;

ivec4 shadowGather(vec3 shadowpos){
    vec4 depths = textureGather(shadowcolor0,shadowpos.xy,0); //BL BR TR TL
    //TL TR BL BR
    return ivec4(depths.w>=shadowpos.z,depths.z>=shadowpos.z,depths.x>=shadowpos.z,depths.y>=shadowpos.z);
}

float shadowSampleSinglePixelMode(vec3 shadowpos){
    return float(texelFetch(shadowcolor0,ivec2(shadowpos.xy*textureSize(shadowcolor0,0)),0).x>=shadowpos.z);
}

float shadowSampleCheapFilterMode(vec3 shadowpos){
    ivec4 visibilities = shadowGather(shadowpos);
    vec2 mix2d = fract(shadowpos.xy*textureSize(shadowcolor0,0));
    mix2d = fract(mix2d+0.5);

    vec2 UD = mix(visibilities.xy,visibilities.zw,mix2d.y);
    return mix(UD.x,UD.y,mix2d.x);
}

float shadowSampleAngledMode(vec3 shadowpos){

    ivec4 visibilities = shadowGather(shadowpos);
    vec2 mix2d = fract(shadowpos.xy*textureSize(shadowcolor0,0));

    mix2d = fract(mix2d+0.5)-0.5;
    float retVal= visibilities[(mix2d.y>0?2:0)+(mix2d.x>0?1:0)];

    if(abs(mix2d.x)+abs(mix2d.y)<0.5){
        retVal=clamp(visibilities.x+visibilities.y+visibilities.z+visibilities.w-2,-1,1)*0.5+0.5;
        if(abs(visibilities.x+visibilities.z-visibilities.y-visibilities.w)>1.5)
        retVal = mix2d.x<0?visibilities.x:visibilities.y;

        if(abs(visibilities.x+visibilities.y-visibilities.z-visibilities.w)>1.5)
        retVal = mix2d.y<0?visibilities.x:visibilities.z;
    }
    return retVal;
}

float shadowSamplePixelSoftMode(vec3 shadowpos){
    float totalValue = 0;
    for(int x=-1;x<=1;x+=2){
        for(int y=-1;y<=1;y+=2){
            vec2 sampleCoord = shadowpos.xy+oneShadowPixel*ivec2(x,y);
            vec4 depths = textureGather(shadowcolor0,sampleCoord,0); //BL BR TR TL
            depths = vec4(depths.x>shadowpos.z,depths.y>shadowpos.z,depths.z>shadowpos.z,depths.w>shadowpos.z);
            totalValue+=(depths.x+depths.y)+(depths.z+depths.w);
        }
    }
    return totalValue/16.0;
}

float shadowSampleSoftMode(vec3 shadowpos){
    float totalValue = 0;
    float totalWeight = 9;

    const int texelRadius = 2;

    vec2 shadowposFract = fract(0.5+fract(shadowpos.xy*SHADOW_RESOLUTION));
    for(int x=-texelRadius;x<=texelRadius;x+=1){
        for(int y=-texelRadius;y<=texelRadius;y+=1){
            vec2 sampleCoord = shadowpos.xy+oneShadowPixel*vec2(x,y);
            float depth = texelFetch(shadowcolor0,ivec2(sampleCoord*SHADOW_RESOLUTION+0.5),0).x;

            float distToCenter=length(vec2(x,y)-shadowposFract);
            float weight = 1.0/max(0.4,distToCenter);

            totalValue+=float(depth>=shadowpos.z)*weight;
            totalWeight+=weight;
        }
    }
    return totalValue/totalWeight;
}


float shadowSample(vec3 shadowpos){
    if(shadowpos.x<0)
        return 1;

    #if SHADOW_SAMPLING_MODE==0
    return shadowSampleSinglePixelMode(shadowpos);
    #elif SHADOW_SAMPLING_MODE==1
    return shadowSampleCheapFilterMode(shadowpos);
    #elif SHADOW_SAMPLING_MODE==2
    return shadowSampleAngledMode(shadowpos);
    #elif SHADOW_SAMPLING_MODE==3
    return shadowSamplePixelSoftMode(shadowpos);
    #elif SHADOW_SAMPLING_MODE==4
    return shadowSampleSoftMode(shadowpos);
    #else
    return 0;
    #endif
}

float shadowSampleCheapest(vec3 shadowpos){
    if(shadowpos.x<0)
        return 1;
    return shadowSampleSinglePixelMode(shadowpos);
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



vec3 shadowmapSample(vec3 worldPos, vec3 normal, float subsurface){
    #if PIXEL_LOCK_SHADOWMAP >0
    worldPos = pixelLock(worldPos+normal*0*0.01,1.0/PIXEL_LOCK_SHADOWMAP);
    #endif
    if(hasCeiling) return vec3(0);
    worldPos-=cameraPosition;
    vec3 lightSrcPosRel = (gbufferModelViewInverse*vec4(shadowLightPosition,1)).xyz;
    lightSrcPosRel-=worldPos;
    float nol = max(0,dot(normalize(lightSrcPosRel),normal));
    float worldPosLen = max(0,(length(worldPos)-2)*0.01);
    vec3 biasNormal = abs(normal);
    biasNormal = (biasNormal.x>=max(biasNormal.y,biasNormal.z))?vec3(1,0,0):(biasNormal.y>biasNormal.z?vec3(0,1,0):vec3(0,0,1));
    biasNormal = sign(normal)*biasNormal;
    vec3 shadowPos = worldSpaceToShadowSunBiased(worldPos+clamp(worldPosLen,1e-1,0.8)*biasNormal);
    float sampl = shadowSample(shadowPos);
    float strength = (nol*sampl)*0.8+0.2;
    #if SUBSURFACE_MODE==2 && defined SUN_SHADOW_SUBSURFACE
    if(subsurface>0)
    {
        shadowPos = worldSpaceToShadow(worldPos-clamp(mix(nol*-0.5+0.1,0.5,max(0,worldPosLen-0.1)),0,1)*biasNormal);
        float sunHitDepth = shadowDepthToLinear(getShadowDepth(shadowPos.xy));
        float actualHitDepth = shadowDepthToLinear(shadowPos.z);
        float subSurfaceDepth = max(0,(sunHitDepth-actualHitDepth))*1.79+0.01;
        subSurfaceDepth = min(-0.15,-3*subSurfaceDepth);

        float subsurfaceStrength = 0.66*exp(subSurfaceDepth/max(0.01,subsurface));
        subsurfaceStrength=max(0,subsurfaceStrength);
        strength=sqrt(strength*strength+subsurfaceStrength*subsurfaceStrength);
    }
    #endif
    return (strength)*(sunAngle>0.5?moonColor:sunColor);
}

vec3 shadowmapSampleFog(vec3 worldPos){
    if(hasCeiling) return vec3(0);
    if(sunAngle>0.5)
        return vec3(0.1);
    worldPos-=cameraPosition;
    vec3 shadowPos =  worldSpaceToShadow(worldPos);
    float strength = FOG_BRIGHTNESS_SUN*shadowSampleCheapest(shadowPos);
    return strength*(sunAngle>0.5?moonColor:sunColor);
}