#ifndef VOXY_PATCH
#version 430 compatibility
#endif

#include "/lib/settings.glsl"
#include "/lib/util/materialId.glsl"

#ifdef VOXY_PATCH
    #if MATERIALS_TYPE>=1
        #define NEEDS_MATERIAL_ID
        #define HARDCODED_MATERIAL
        #define MATERIALS_TYPE 0
    #endif

    #if MATERIALS_TYPE < 0
        #undef WRITE_MATERIALS
    #endif
#else


#if MATERIALS_TYPE < 0
    #undef WRITE_MATERIALS
#endif

#if (defined WRITE_MATERIALS) && (MATERIALS_TYPE == 0)
    #define NEEDS_MATERIAL_ID
    #define HARDCODED_MATERIAL
    flat in uvec4 hardcodedMaterialInfo;
    #if !(HARDCODED_EMISSIVE_SELECTIVITY==-1)
        #define NEEDS_MATERIAL_ID
    #endif
#endif

#ifdef TEXTURED
in vec2 texcoord;
uniform sampler2D gtexture;
    #if MATERIALS_TYPE ==1
uniform sampler2D specular;
uniform sampler2D normals;
flat in mat3 normalRotator;
    #endif
#endif

#ifdef LIT
in vec2 lmcoord;
uniform sampler2D lightmap;
#endif

#ifdef VERTEX_NORMALS
in vec3 normal;
#endif

#ifdef ALPHATEST
uniform float alphaTestRef = 0.1;
#endif

#ifdef ENTITY
uniform vec4 entityColor;
#endif

#ifdef BONUS_STUFF
void doBonusStuff();
#endif

#ifdef BASIC
in flat vec4 glcolor;
#else
in vec4 glcolor;
#endif

#ifdef NEEDS_MATERIAL_ID
flat in int materialID;
#endif

#if defined MAYBE_END_GATEWAY && defined GATEWAYS_IN_GBUFFER
uniform float viewWidth, viewHeight;
#include "/lib/renderComponents/endGateway.glsl"
#endif

#ifdef TRANSLUCENT
    #ifdef WRITE_MATERIALS
    /* RENDERTARGETS: 1,2,5,4 */
    #else
    /* RENDERTARGETS: 1,2,5 */
    #endif
#else
    #ifdef WRITE_MATERIALS
    /* RENDERTARGETS: 0,2,5,3 */
    #else
    /* RENDERTARGETS: 0,2,5 */
    #endif
#endif

#endif


#ifdef HAND
    #define NORMAL_A 0.5
#elif defined TRANSLUCENT
    #define NORMAL_A 1
#else
    #define NORMAL_A 0
#endif

#ifndef POM_ELLIGIBLE
    #undef POM
#endif

#ifdef POM
in vec2 differential;
flat in ivec2 baseTexpos;
flat in ivec2 texsize;
uniform ivec2 atlasSize;
uniform float far, near;

const float pomDepth = 0.25*POM_DEPTH_STRENGTH;

float rayDepth=0;

void pomEdge(inout vec2 tc){
    #ifdef POM_DISCARD
    if(tc.x<0 || tc.y<0 || tc.x>=texsize.x || tc.y>=texsize.y)
        discard;
    #endif

    #ifdef POM_WRAP
    tc= fract(tc/texsize)*texsize;
    #else
    tc= clamp(tc,vec2(0),texsize-1e-5);
    #endif
}

vec2 doPixPom(vec2 initialTc){

    vec2 tc = initialTc;
    for(int i = 0; i<pomSamples; i++){
        tc =initialTc+differential*rayDepth;

        pomEdge(tc);
        vec2 remainingDepthTillTransition = (1-fract(tc*sign(differential)))/abs(differential);
        rayDepth+=min(remainingDepthTillTransition.x,remainingDepthTillTransition.y);
        float texdepth = float(1.0-texelFetch(normals,baseTexpos+ivec2(tc),0).a)*pomDepth;
        rayDepth+=exp2(-16);
        if(rayDepth>= texdepth){
            break;
        }

    }
    return tc;
}
vec2 doSparsePom(vec2 initialTc){
    vec2 tc;
    for(int i = 0; i<pomSamples; i++){
        rayDepth = i*(pomDepth/pomSamples);
        tc =initialTc+differential*rayDepth;
    #if POM_MODE==2
        vec2 c = clamp(tc,vec2(0),texsize);
        if(c!=tc){
            tc=c;
            break;
        }
    #else
        pomEdge(tc);
    #endif
        float depth = float(1.0-texelFetch(normals,(baseTexpos+ivec2(tc)),0).a)*pomDepth;

        if(rayDepth+1e-4>=depth){
            break;
        }
    }
    return tc;
}

vec2 doPom(vec2 tc){
    vec2 initialTc = tc*atlasSize-baseTexpos;
    vec2 ret;

    #if POM_MODE==0
    ret = doSparsePom(initialTc);
    #elif POM_MODE==1
    ret= doPixPom(initialTc);
    #else
    doSparsePom(initialTc);
    float maxDepthDif = ((pomSamples-2)/(ceil(abs(differential.x))+ceil(abs(differential.y))));
    rayDepth=max(0,rayDepth-maxDepthDif);

    ret= doPixPom(initialTc);
    #endif

    #ifdef POM_WRITE_DEPTH
    rayDepth = float(1.0-texelFetch(normals,(baseTexpos+ivec2(ret)),0).a)*pomDepth;
    #endif
    return (baseTexpos+(0.5+floor(ret)))/atlasSize;

}
uniform mat4 gbufferProjectionInverse;
#include "/lib/util/conversions.glsl"
#endif

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 normalOut;

#ifdef VANILLA_FALLBACK
layout(location = 2) out vec4 vanillaLighting;
#endif
#ifdef WRITE_MATERIALS
layout(location = 3) out uvec4 materialInfo;
#endif

/*
const vec4 colortex1ClearColor = vec4(0.0,0.0,0.0,0.0);
*/

#ifdef VOXY_PATCH
void handleFragment(vec4 glcolor,vec3 normal, vec2 lmcoord, vec4 voxySampledColor, int materialID)

#if 0
;//for my IDE :/
#endif

#else
void main()
#endif
{
#ifdef TEXTURED
    #ifdef POM
        vec2 newTexcoord=doPom(texcoord);
        #ifdef POM_WRITE_DEPTH
        rayDepth = length(vec3(differential/texsize,1))*rayDepth;
        gl_FragDepth=depthToBuf(depthToLinear(gl_FragCoord.z)+rayDepth);
        #endif
    #else
//        gl_FragDepth=gl_FragCoord.z;
        #define newTexcoord texcoord
    #endif
#endif

#ifdef LIT
    #ifdef VOXY_PATCH
    vec4 lighting = voxyLighting(lmcoord);
    #else
    vec4 lighting = texture(lightmap, lmcoord);
    #endif
#elif defined BASIC
    bool isLeash = length(glcolor.xyz-vec3(0.425,0.34,0.25))<0.5;
    vec4 lighting = isLeash?vec4(0.9,0.9,0.9,1):vec4(1.0);
#else
    vec4 lighting = vec4(1.0);
#endif

#ifdef MAYBE_END_GATEWAY
    bool isEndGateway = materialID==55498;
    vec4 sampledColor;

    if(isEndGateway){
        lighting=vec4(1.0);
        sampledColor = vec4(doEndGateway(gl_FragCoord.xy/vec2(viewWidth,viewHeight)),1);
    }else{
        sampledColor = glcolor*texture(gtexture, newTexcoord);
    }

#elif defined VOXY_PATCH
    vec4 sampledColor = voxySampledColor*glcolor;
#elif defined TEXTURED
    vec4 sampledColor = glcolor * texture(gtexture, newTexcoord);
#else
    vec4 sampledColor = glcolor * lighting;
#endif

#ifdef ENTITY
    sampledColor.rgb = mix(sampledColor.rgb, entityColor.rgb, entityColor.a);
#endif

#ifdef ALPHATEST
    if (sampledColor.a < alphaTestRef) {
        discard;
    }
#endif

#ifdef VERTEX_NORMALS
    #if (defined TEXTURED) && (MATERIALS_TYPE == 1)
    vec4 pbrNormalSample = texture(normals,newTexcoord);

    pbrNormalSample.xy = (pbrNormalSample.xy-0.5)*(2*PBR_NORMALS_STRENGTH);
    vec3 texNormal = vec3(pbrNormalSample.xy,sqrt(1.0 - dot(pbrNormalSample.xy, pbrNormalSample.xy)));

    texNormal = normalize(normalRotator*texNormal);

    #if (defined POM) && DEBUG_SPECIAL_VIEW==104
        bool checker = bool((int(floor(texcoord.x*atlasSize.x))+int(floor(texcoord.y*atlasSize.y)))&1);
        sampledColor.xyz=vec3(abs(max(differential.xy,checker?0:-1)),0);
    //        sampledColor.xyz=vec3(pbrNormalSample.a);
    #endif

    normalOut = vec4((texNormal+1)*0.5,NORMAL_A);
    #else
    normalOut = vec4((normal+1)*0.5,NORMAL_A);
    #endif

    #ifdef TRANSLUCENT
    if(sampledColor.a<=translucentPrecedenceCutoff)
        normalOut.a=0;
    #endif
#endif


//TODO the translucent part is for viewing fully lit stuff thru transparents, prolly a better solution tho
#if defined VANILLA_FALLBACK && ((!defined TRANSLUCENT) || (defined FAKE_TRANSLUCENT))
    vanillaLighting=lighting;
#endif

    color = sampledColor;

#ifdef WRITE_MATERIALS
    #if MATERIALS_TYPE == 0 //hardcoded
        #ifdef VOXY_PATCH
    materialInfo = getHardcodedMaterial(materialID);
        #else
    materialInfo = hardcodedMaterialInfo;
        #endif

        #if !(HARDCODED_EMISSIVE_SELECTIVITY==-1)
    if(materialInfo.a!=255){
        vec3 lightColor = getMaterialColor(materialID);
        float brightness = dot(color.rgb/glcolor.rgb,normalize(lightColor));
        brightness*=brightness;
        brightness = brightness*HARDCODED_EMISSIVE_SELECTIVITY + (1-HARDCODED_EMISSIVE_SELECTIVITY);
        materialInfo.a=uint(clamp(brightness,0,1)*materialInfo.a);
    }
        #endif

    #elif MATERIALS_TYPE == 1 //PBR pack
    materialInfo = uvec4(round(clamp(texture(specular,newTexcoord)*255.0,0,255)));
    #endif

    #ifdef TRANSLUCENT

    if(sampledColor.a<translucentPrecedenceCutoff)
        materialInfo.a=255;
    #endif
#endif


    #ifdef BONUS_STUFF
    doBonusStuff();
    #endif
}