#version 430 compatibility
#include "/lib/settings.glsl"

#define SIZE 16
const vec2 workGroupsRender = vec2(LIGHTING_RENDERSCALE,LIGHTING_RENDERSCALE);

const int numAngles = 2*SSAO_QUALITY+1;
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

#define TEMPORAL_DITHER
#include "/lib/util/dither.glsl"
#include "/lib/util/conversions.glsl"

#define TWOPI 6.28318530718

float doSsao(vec2 texcoord, vec3 normal){

    ivec2 texSize = textureSize(colortex5,0);
    float solidDepth=texelFetch(colortex5,ivec2(texcoord*texSize),0).x;
    float dither = dither(ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy));


    #ifdef TAA
    dither=temporalNoise(dither);
    #endif

    if(solidDepth>0.99999 || bool(floatBitsToUint(solidDepth)&1u))
    return 1;
    vec4 worldPos = gbufferProjectionInverse*(vec4(texcoord,solidDepth,1)*2-1);
    worldPos/=worldPos.w;

    float radius = (SSAO_RADIUS)/depthToLinear(solidDepth);
    radius*=0.5;
    radius = min(radius*(0.01+sqrt(dither)),0.10);

    float sum = 0;


    dither = fract(23*dither);

    for(int a = 0; a<numAngles;a++){
        float angle = fract(float(a)/numAngles-dither)*TWOPI;
        vec4 pos;
        pos.xy = texcoord + vec2(cos(angle),sin(angle))*radius;
        pos.z = texelFetch(colortex5,clamp(ivec2(pos.xy*texSize),ivec2(0),texSize-1),0).x;

        if(bool(floatBitsToUint(pos.z)&1u))
            continue;

        pos = gbufferProjectionInverse*vec4(pos.xyz*2.0-1.0,1.0);
        pos.xyz=pos.xyz/pos.w-worldPos.xyz;

        float attenuation = length(pos.xyz);
        attenuation = clamp((SSAO_RADIUS*2.0)/length(pos.xyz),1.0-SSAO_LEAK_REDUCTION,1.0);

        float wallAngle = asin(clamp(dot(normalize(pos.xyz),normal)*attenuation,0,1));
        sum += 1-cos(2*wallAngle);
    }



    //0 = fully lit, 1 = fully occluded
    float ssao = sum*(0.25*PI/numAngles);

    //    return ssao>0.01?0:1;
    ssao*=SSAO_STRENGTH;
    return clamp(1-ssao,0.2,1);
}


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

    normal = transpose(mat3(gbufferModelViewInverse))* normalize(normal*2-1);

    if(emissive>0.4)
        return;

    voxelLighting.a = doSsao(jitteredTexcoord, normal);

    #if DEBUG_SPECIAL_VIEW == 103
    imageStore(colorimg19,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),vec4(voxelLighting.aaa,0));
    #endif

    if(voxelLighting.a>0.99)
        return;


    voxelLighting.rgb*=voxelLighting.a;
    imageStore(colorimg6,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),voxelLighting);

}