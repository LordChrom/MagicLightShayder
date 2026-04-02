#ifdef VOXY_PATCH
#include "/lib/settings.glsl"

#ifdef VANILLA_FALLBACK
layout(location = 2) out vec4 vanillaLighting;
#endif

#else
#version 430 compatibility
#include "/lib/settings.glsl"

#if MATERIALS_TYPE < 0
    #undef WRITE_MATERIALS
#endif

#if (defined WRITE_MATERIALS) && (MATERIALS_TYPE == 0)
    #define NEEDS_MATERIAL_ID
#endif

#ifdef TEXTURED
in vec2 texcoord;
uniform sampler2D gtexture;
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

#ifdef VANILLA_FALLBACK
    #if defined TRANSLUCENT && defined TRANSLUCENT_SEPARATE_BUFFER
    /* RENDERTARGETS: 1,2,5 */
    #elif defined WRITE_MATERIALS
    /* RENDERTARGETS: 0,2,5,3 */
    layout(location = 3) out uvec4 materialInfo;
    #else
    /* RENDERTARGETS: 0,2,5 */
    #endif
layout(location = 2) out vec4 vanillaLighting;
#else
    #if defined TRANSLUCENT && defined TRANSLUCENT_SEPARATE_BUFFER
    /* RENDERTARGETS: 1,2 */
    #elif defined WRITE_MATERIALS
    /* RENDERTARGETS: 0,2,3 */
    layout(location = 2) out uvec4 materialInfo;
    #else
    /* RENDERTARGETS: 0,2 */
    #endif
#endif

#endif


#ifdef HAND
#define HAND_MASK 0.5
#else
#define HAND_MASK 0
#endif

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 normalOut;

#ifdef TRANSLUCENT_SEPARATE_BUFFER
/*
const vec4 colortex1ClearColor = vec4(0.0,0.0,0.0,0.0);
*/
#endif

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
    #ifdef TRANSLUCENT
    if(sampledColor.a>translucentPrecedenceCutoff)
        normalOut = vec4((normal+1)*0.5,1);
    #else
        normalOut = vec4((normal+1)*0.5,HAND_MASK);
    #endif
#endif

    color = sampledColor;

//TODO the translucent part is for viewing fully lit stuff thru transparents, prolly a better solution tho
#if defined VANILLA_FALLBACK && !defined TRANSLUCENT
    vanillaLighting=lighting;
#endif

#ifdef WRITE_MATERIALS

    #if MATERIALS_TYPE == 0 //hardcoded

    float subsurface = ((materialID%10000)==15)?0.33:0;
    float porosity = 0;

    materialInfo=clamp(uvec4(
        0,
        0,
        (porosity>0.01)?porosity*64:64+subsurface*190.0,
        0
    ),0,255);


    #elif MATERIALS_TYPE == 1 //PBR pack
    materialInfo=uvec4(0);

    #endif
#endif

    #ifdef BONUS_STUFF
    doBonusStuff();
    #endif
}