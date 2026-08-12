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
#include "/lib/util/dither.glsl"

uniform sampler2D colortex2;
uniform sampler2D depthtex2;
uniform sampler2D depthtex0;

uniform sampler2D colortex1;

#ifdef SSAO
uniform mat4 gbufferModelView;
#include "/lib/renderComponents/ssao.glsl"
#endif

#if MATERIALS_TYPE >= 0
uniform usampler2D colortex3;
#endif

#if (DEBUG_SPECIAL_VIEW == 4) || ((DEBUG_SPECIAL_VIEW==104) || (DEBUG_SPECIAL_VIEW==106))
uniform sampler2D colortex4;
#elif DEBUG_SPECIAL_VIEW == 5
uniform sampler2D colortex5;
#elif (DEBUG_SPECIAL_VIEW == 10)  || (DEBUG_SPECIAL_VIEW == 200)
uniform sampler2D colortex10;
#elif DEBUG_SPECIAL_VIEW == 11
uniform sampler2D colortex11;
#elif DEBUG_SPECIAL_VIEW == 105 && !defined SSAO
#include "/lib/util/conversions.glsl"
#endif


void main() {
    float ditherValue = dither(ivec2(gl_FragCoord.xy));

    ivec2 sourceTexpos = ivec2((jitteredTexcoord*textureSize(depthtex0,0)+0.01));

    bool solidTransInFront = texelFetch(colortex1,sourceTexpos,0).a>=1;
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
//        matInfo = texelFetch(colortex4 ,sourceTexpos ,0);
//        if((matInfo.a==255) || matInfo==uvec4(0))
        #endif
            matInfo = texelFetch(colortex3, sourceTexpos, 0);
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



#if (DEBUG_SPECIAL_VIEW == 0) || ((DEBUG_SPECIAL_VIEW==104) || (DEBUG_SPECIAL_VIEW==106))
    funnyDebug=texture(colortex4,jitteredTexcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 1
    funnyDebug=texture(colortex1,jitteredTexcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 2
    ivec2 texpos = ivec2(gl_FragCoord.xy);
    float debugCheckerScale = 7;
    bool checker = bool((int(texpos.x/debugCheckerScale)^int(texpos.y/debugCheckerScale))&1);
    vec3 mult = checker?vec3(1):sign(normal.xyz)*0.2+0.8;
    funnyDebug = abs(normal.xyz)*mult;
#elif DEBUG_SPECIAL_VIEW == 3
    uvec4 mat = texture(colortex3,jitteredTexcoord);
    float funnyEmissive = (mat.a==255)?0.0:(mat.a/254.0);
        funnyDebug=funnyEmissive+mat.rgb*((1.0-funnyEmissive)/255.0);
//        funnyDebug=funnyEmissive*mat.rgb*(1.0/255.0);
#elif DEBUG_SPECIAL_VIEW == 4
    funnyDebug= texture(colortex4,jitteredTexcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 5
    funnyDebug=texture(colortex5,jitteredTexcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 6
    funnyDebug = voxelLighting.xyz;
#elif DEBUG_SPECIAL_VIEW == 7
    funnyDebug = voxelFog.xyz;
#elif (DEBUG_SPECIAL_VIEW == 10) || (DEBUG_SPECIAL_VIEW == 200)
    funnyDebug = texture(colortex10,jitteredTexcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 11
    funnyDebug = texture(colortex11,jitteredTexcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 100
    funnyDebug = vec3(clamp(0.05*sqrt(length(worldPosRelative)),0,1),float(isHand)*0.1,float(depth==1)*0.5);
#elif DEBUG_SPECIAL_VIEW == 101
    funnyDebug = vec3(ditherValue);
#elif DEBUG_SPECIAL_VIEW == 102
    ivec2 texpos = ivec2(gl_FragCoord.xy);
    funnyDebug = vec3((texpos.x^texpos.y)&4,(texpos.x^texpos.y)&2,(texpos.x^texpos.y)&1);
#elif (DEBUG_SPECIAL_VIEW == 103) && (defined SSAO)
    funnyDebug = vec3(ssao);
#elif (DEBUG_SPECIAL_VIEW == 105)
    funnyDebug = vec3(depthToLinear(depth)/4);
#endif
}