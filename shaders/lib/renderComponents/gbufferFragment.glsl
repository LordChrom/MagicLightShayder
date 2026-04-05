#ifndef VOXY_PATCH
#version 430 compatibility
#endif

#include "/lib/settings.glsl"

#ifdef VOXY_PATCH

#ifdef VANILLA_FALLBACK
layout(location = 2) out vec4 vanillaLighting;
#endif

#else

#include "/lib/util/materialId.glsl"

#if MATERIALS_TYPE < 0
    #undef WRITE_MATERIALS
#endif

#if (defined WRITE_MATERIALS) && (MATERIALS_TYPE == 0)
    #define NEEDS_MATERIAL_ID
    #define HARDCODED_MATERIAL
    flat in uvec4 hardcodedMaterialInfo;
    #ifdef SELECTIVE_HARDCODED_EMISSIVE
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
void handleFragment(vec4 glcolor,vec3 normal, vec2 lmcoord, vec4 voxySampledColor)

#if 0
;//for my IDE :/
#endif

#else
void main()
#endif
{

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
        sampledColor = glcolor*texture(gtexture, texcoord);
    }

#elif defined VOXY_PATCH
    vec4 sampledColor = voxySampledColor*glcolor;
#elif defined TEXTURED
    vec4 sampledColor = glcolor * texture(gtexture, texcoord);
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
    vec4 pbrNormalSample = texture(normals,texcoord);

    pbrNormalSample.xy = (pbrNormalSample.xy-0.5)*(2*PBR_NORMALS_STRENGTH);
    vec3 texNormal = vec3(pbrNormalSample.xy,sqrt(1.0 - dot(pbrNormalSample.xy, pbrNormalSample.xy)));

    texNormal = normalRotator*texNormal;
//    texNormal.z=max(0,texNormal.z);
    texNormal=normalize(texNormal);
//        texNormal=normalize(vec3(dot(texNormal,tangent.xyz),dot(texNormal,bitangent),dot(texNormal,normal)));


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
#if defined VANILLA_FALLBACK && !defined TRANSLUCENT
    vanillaLighting=lighting;
#endif

    color = sampledColor;

#ifdef WRITE_MATERIALS
    #if MATERIALS_TYPE == 0 //hardcoded
    materialInfo = hardcodedMaterialInfo;

        #ifdef SELECTIVE_HARDCODED_EMISSIVE
    if(materialInfo.a!=255){
        vec3 lightColor = getMaterialColor(materialID);
        float brightness=clamp(dot(color.rgb,normalize(lightColor)),0,1);
        materialInfo.a=uint(brightness*materialInfo.a);
    }
        #endif

    #elif MATERIALS_TYPE == 1 //PBR pack
    materialInfo = uvec4(round(clamp(texture(specular,texcoord)*255.0,0,255)));
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