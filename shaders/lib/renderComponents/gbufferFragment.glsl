#version 430 compatibility

#include "/lib/settings.glsl"

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

#ifdef HAND
#define HAND_MASK 0.5
#else
#define HAND_MASK 0
#endif

#ifdef BONUS_STUFF
void doBonusStuff();
#endif

#ifdef BASIC
in flat vec4 glcolor;
#else
in vec4 glcolor;
#endif

#ifndef GATEWAYS_IN_GBUFFER
#undef MAYBE_END_GATEWAY
#endif

#ifdef MAYBE_END_GATEWAY
in float material;
uniform float viewWidth, viewHeight;
#include "/lib/renderComponents/endGateway.glsl"
#endif

#ifdef VANILLA_FALLBACK
    #if defined TRANSLUCENT && defined TRANSLUCENT_SEPARATE_BUFFER
    /* RENDERTARGETS: 1,2,5 */
    #else
    /* RENDERTARGETS: 0,2,5 */
    #endif
layout(location = 2) out vec4 vanillaLighting;
#else
    #if defined TRANSLUCENT && defined TRANSLUCENT_SEPARATE_BUFFER
    /* RENDERTARGETS: 1,2 */
    #else
    /* RENDERTARGETS: 0,2 */
    #endif
#endif


layout(location = 0) out vec4 color;
layout(location = 1) out vec4 normalOut;

#ifdef TRANSLUCENT_SEPARATE_BUFFER
/*
const vec4 colortex1ClearColor = vec4(0.0,0.0,0.0,0.0);
*/
#endif

void main() {

#ifdef LIT
    vec4 lighting = texture(lightmap, lmcoord);
#elif defined BASIC
    bool isLeash = length(glcolor.xyz-vec3(0.425,0.34,0.25))<0.5;
    vec4 lighting = isLeash?vec4(0.9,0.9,0.9,1):vec4(1.0);
#else
    vec4 lighting = vec4(1.0);
#endif

#ifdef MAYBE_END_GATEWAY
    bool isEndGateway = abs(material-55498)<20;
    vec4 sampledColor;

    if(isEndGateway){
        lighting=vec4(1.0);
        sampledColor = vec4(doEndGateway(gl_FragCoord.xy/vec2(viewWidth,viewHeight)),1);
    }else{
        sampledColor = glcolor*texture(gtexture, texcoord);
    }

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

    #ifdef BONUS_STUFF
    doBonusStuff();
    #endif
}