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
    float ditherValue = dither(ivec2(gl_FragCoord.xy));

    ivec2 sourceTexpos = ivec2((jitteredTexcoord*textureSize(depthtex0,0)+0.01));

    bool solidTransInFront = texelFetch(colortex3,sourceTexpos,0).a>=1;
    float depth = texelFetch(depthtex0,sourceTexpos,0).x;
    vec4 normal = texelFetch(colortex2,sourceTexpos,0);
    float solidDepth;

    normal.xyz = normalize(normal.xyz*2-1);
    bool isHand = normal.a>0.4 && normal.a<0.6;
    if(solidTransInFront){
        solidDepth=depth;
    }else{
        solidDepth = texelFetch(depthtex2,sourceTexpos,0).x;
    }
    vec4 worldPosRelative = vec4(vec3(jitteredTexcoord,solidDepth)*2-1,1);
    if(isHand){
        worldPosRelative.z=depth/MC_HAND_DEPTH;
    }

    float subsurface = 0;
    float emissive = 0;
#if MATERIALS_TYPE >= 0
    uvec4 matInfo = uvec4(0);

    if(!isHand){
        #ifndef FORWARD_TRANSLUCENTS
//        matInfo = texelFetch(colortex1 ,sourceTexpos ,0);
//        if((matInfo.a==255) || matInfo==uvec4(0))
        #endif
            matInfo = texelFetch(colortex8, sourceTexpos, 0);
    }

    subsurface = clamp(float(int(matInfo.b)-64)/190.0, 0.0,1.0);

    //TODO subsurface on porous materials like wool
//    if(matInfo.b>=20u && matInfo.b<=64u) subsurface=float(matInfo.b)/64;
    if(matInfo.a!=255)
        emissive = (matInfo.a/254.0);
#endif

    worldPosRelative = gbufferProjectionInverse*worldPosRelative;
    worldPosRelative/=worldPosRelative.w;
    worldPosRelative.xyz = mat3(gbufferModelViewInverse)*worldPosRelative.xyz+gbufferModelViewInverse[3].xyz;


    voxelLighting = vec3(0);
    if(!((depth==1)|| solidTransInFront))
        voxelLighting = lightingSample(worldPosRelative.xyz+cameraPosition,normal.xyz,subsurface,ditherValue)+(EMISSIVE_BRIGHTNESS*emissive);

#ifdef SSAO
    float ssao;
    if(emissive<0.4 && !isHand && (depth!=1)){
        ssao = doSsao(jitteredTexcoord, normal.xyz, solidDepth, ditherValue);
        voxelLighting*=ssao;
    }
#endif


#if (DEBUG_SPECIAL_VIEW == 103) && (defined SSAO)
    voxelLighting = vec3(ssao);
#endif
}