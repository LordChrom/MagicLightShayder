#version 430 compatibility
#include "/lib/settings.glsl"
#ifdef TAA
#include "/lib/util/taaJitter.glsl"
#endif


#define SIZE 16
const vec2 workGroupsRender = vec2(LIGHTING_RENDERSCALE,LIGHTING_RENDERSCALE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

layout (rgba16f) uniform writeonly restrict image2D colorimg6;

#if DEBUG_SPECIAL_VIEW >= 0
layout (rgba8) uniform writeonly restrict image2D colorimg19;
#endif



uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform vec3 cameraPosition;

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

#if MATERIALS_TYPE >= 0
uniform usampler2D colortex8;
#endif

#include "/lib/util/uniforms/frameCounter"
#include "/lib/lighting/lightWrapper.glsl"
#define TEMPORAL_DITHER
#include "/lib/util/dither.glsl"

#ifdef SSAO
#include "/lib/renderComponents/ssao.glsl"
#endif


void main() {
    vec2 jitteredTexcoord = (vec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)+0.5);
    #ifdef TAA
    jitteredTexcoord+=unscaledJitter();
    #endif
    jitteredTexcoord/=imageSize(colorimg6);

    vec3 normal = texture(colortex2,jitteredTexcoord).xyz;
    float solidDepth = texture(colortex5,jitteredTexcoord).x;
    #if MATERIALS_TYPE >= 0
    uvec4 matInfo = texture(colortex8,jitteredTexcoord);
    #endif


    float albedoA = texelFetch(colortex1,ivec2(jitteredTexcoord*textureSize(colortex1,0)),0).a;
    if(solidDepth==1.0 || albedoA<1){
        imageStore(colorimg6,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),vec4(0));
        return;
    }
    vec4 worldPosRelative = vec4(jitteredTexcoord,solidDepth,1);


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



    normal = normalize(normal);

    float ditherValue = dither(ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy));

    vec4 voxelLighting=vec4(0,0,0,1);

    #ifdef SSAO
    if(emissive<0.4){
        voxelLighting.a = doSsao(jitteredTexcoord, normal, ditherValue);
    }
    #if DEBUG_SPECIAL_VIEW == 103
    imageStore(colorimg19,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),vec4(voxelLighting.aaa,0));
    #endif
    #endif

    voxelLighting.rgb = lightingSample(worldPosRelative.xyz+cameraPosition,normal,subsurface,ditherValue)+(EMISSIVE_BRIGHTNESS*emissive);
    #ifdef SSAO
    voxelLighting.rgb*=voxelLighting.a;
    #endif

    imageStore(colorimg6,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),voxelLighting);
}