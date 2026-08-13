#include "/lib/settings.glsl"

in vec2 jitteredTexcoord;

#if DEBUG_SPECIAL_VIEW >= 0
/* RENDERTARGETS: 6,19 */
layout(location = 1) out vec3 funnyDebug;
#else
/* RENDERTARGETS: 6 */
#endif

layout(location = 0) out vec3 voxelLighting;


uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform vec3 cameraPosition;
//uniform vec2 scaledScreenDim;

#include "/lib/lightingWrapper/lightSampler.glsl"
#define TEMPORAL_DITHER
#include "/lib/util/dither.glsl"

uniform sampler2D colortex2;
uniform sampler2D depthtex2;
uniform sampler2D depthtex0;

uniform sampler2D colortex3;

#ifdef SSAO
uniform mat4 gbufferModelView;
#include "/lib/renderComponents/ssao.glsl"
#endif

#if MATERIALS_TYPE >= 0
uniform usampler2D colortex8;
#endif

#if ((DEBUG_SPECIAL_VIEW==104) || (DEBUG_SPECIAL_VIEW==106))
uniform sampler2D colortex1;
#elif (DEBUG_SPECIAL_VIEW == 10)  || (DEBUG_SPECIAL_VIEW == 200)
uniform sampler2D colortex10;
#elif DEBUG_SPECIAL_VIEW == 105 && !defined SSAO
#include "/lib/util/conversions.glsl"
#endif


void main() {
    vec4 normal = texture(colortex2,jitteredTexcoord);
    float solidDepth = texture(depthtex2,jitteredTexcoord).x;
    #if MATERIALS_TYPE >= 0
    uvec4 matInfo = texture(colortex8,jitteredTexcoord);
    #endif

    float ditherValue = dither(ivec2(gl_FragCoord.xy));

    bool isHand = normal.a>0.4 && normal.a<0.6;

    if(solidDepth==1)
        return;
    vec4 worldPosRelative = vec4(jitteredTexcoord,solidDepth,1);

    if(isHand){
        #if IRIS_VERSION < 11008
        return;
        #else
        worldPosRelative.z=texture(depthtex0,jitteredTexcoord).x/MC_HAND_DEPTH;
        #endif
    }

    worldPosRelative.xyz=worldPosRelative.xyz*2-1;
    worldPosRelative = gbufferProjectionInverse*worldPosRelative;
    worldPosRelative/=worldPosRelative.w;
    worldPosRelative.xyz = mat3(gbufferModelViewInverse)*worldPosRelative.xyz+gbufferModelViewInverse[3].xyz;

    float subsurface = 0;
    float emissive = 0;
#if MATERIALS_TYPE >= 0
    subsurface = clamp(float(int(matInfo.b)-64)/190.0, 0.0,1.0);

    //TODO subsurface on porous materials like wool
//    if(matInfo.b>=20u && matInfo.b<=64u) subsurface=float(matInfo.b)/64;
    if(matInfo.a!=255)
        emissive = (matInfo.a/254.0);
#endif



    normal.xyz = normalize(normal.xyz*2-1);

    float ssao=1;
    #ifdef SSAO
    if(emissive<0.4 && !isHand){
        ssao = doSsao(jitteredTexcoord, normal.xyz, solidDepth, ditherValue);
    }
    #endif

    voxelLighting = ssao*lightingSample(worldPosRelative.xyz+cameraPosition,normal.xyz,subsurface,ditherValue)+(EMISSIVE_BRIGHTNESS*emissive);

#if (DEBUG_SPECIAL_VIEW == 103) && (defined SSAO)
    voxelLighting = vec3(ssao);
#endif
}