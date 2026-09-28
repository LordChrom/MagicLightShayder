#version 430 compatibility
#include "/lib/settings.glsl"

#define SIZE 16
const vec2 workGroupsRender = vec2(LIGHTING_RENDERSCALE,LIGHTING_RENDERSCALE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

layout (rgba16f) uniform writeonly restrict image2D colorimg6;

#if DEBUG_SPECIAL_VIEW >= 0
layout (rgba8) uniform writeonly restrict image2D colorimg19;
#endif

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform sampler2D colortex2,colortex5,colortex6;
uniform usampler2D colortex8;

#ifdef TAA
#include "/lib/util/taaJitter.glsl"
#endif

#include "/lib/util/dither.glsl"
#include "/lib/renderComponents/ssao.glsl"


void main(){
    vec2 jitteredTexcoord = (vec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)+0.5);
    #ifdef TAA
    jitteredTexcoord+=unscaledJitter();
    #endif
    jitteredTexcoord/=imageSize(colorimg6);

    #if MATERIALS_TYPE >= 0
    uvec4 matInfo = texture(colortex8,jitteredTexcoord);
    #endif

    vec4 voxelLighting = texelFetch(colortex6,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),0);
    vec3 normal = texture(colortex2,jitteredTexcoord).xyz;

    float emissive = 0;
    #if MATERIALS_TYPE >= 0
//    subsurface = clamp(float(int(matInfo.b)-64)/190.0, 0.0,1.0);

    //TODO subsurface on porous materials like wool
    //    if(matInfo.b>=20u && matInfo.b<=64u) subsurface=float(matInfo.b)/64;
    if(matInfo.a!=255)
        emissive = (matInfo.a/254.0);
    #endif

    normal = normalize(normal*2-1);

    if(emissive>0.4){
        return;
    }
    float ditherValue = dither(ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy));
    voxelLighting.a = doSsao(jitteredTexcoord, normal, ditherValue);

    #if DEBUG_SPECIAL_VIEW == 103
    imageStore(colorimg19,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),vec4(voxelLighting.aaa,0));
    #endif

    if(voxelLighting.a>0.99)
        return;


    voxelLighting.rgb*=voxelLighting.a;
    imageStore(colorimg6,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),voxelLighting);

}