#version 430
#include "/lib/settings.glsl"
#include "/lib/util/dither.glsl"
uniform vec2 scaledScreenDim;
#include "/lib/util/taaJitter.glsl"

#define SIZE 16
const vec2 workGroupsRender = vec2(LIGHTING_RENDERSCALE,LIGHTING_RENDERSCALE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;
layout (r8) uniform writeonly restrict image2D swrtRayHits;
//layout (rgba16f) uniform writeonly restrict image2D colorimg6;

uniform sampler2D depthtex2;
uniform sampler2D colortex2;


const uint maxSteps = 15u;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform vec3 cameraPosition;

#include "/lib/lighting/swrt/swrtSampler.glsl"

void main(){
    vec2 jitteredTexcoord = ((gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)+0.5)/scaledScreenDim;
    #ifdef TAA
    jitteredTexcoord+=jitter();
    #endif
    float solidDepth = texture(depthtex2,jitteredTexcoord).x;
    vec4 normal = texture(colortex2,jitteredTexcoord);
    vec4 worldPos = vec4(jitteredTexcoord,solidDepth,1);


    worldPos.xyz=worldPos.xyz*2-1;
    worldPos = mat3x4(gbufferProjectionInverse)*worldPos.xyz+gbufferProjectionInverse[3];
    worldPos/=worldPos.w;
    worldPos.xyz = mat3(gbufferModelViewInverse)*worldPos.xyz+gbufferModelViewInverse[3].xyz;



    worldPos.xyz+=clamp(length(worldPos.xyz)*0.001,0.04,0.1)*normalize(normal.xyz*2-1);
    worldPos.xyz+=cameraPosition;
    ivec3 areaPos = worldPosToSWRT(worldPos.xyz);


//    vec3 color = vec3(0);
    if((areaPos.x<0||areaPos.y<0||areaPos.z<0||
        areaPos.x>=SWRT_SIZE||areaPos.y>=SWRT_SIZE||areaPos.z>=SWRT_SIZE)
    )
        return;

    float ditherValue = bayer128(ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)>>1);
    #ifdef SWRT_NOISY_PENUMBRAS
    ditherValue = temporalNoise(ditherValue);
    #endif

    unitShift = getUnitShift();

    uint index = ((gl_LocalInvocationID.x&1u)<<1) + (gl_LocalInvocationID.y&1u) + 4u*gl_LocalInvocationID.z;
    uint light = getListLight(areaPos,unitShift,index);

    if(!bool(light&LIGHT_VALID_BIT))
        return;
    vec3 displacementToLight = uncheckedUnpackListedLight(light)+ 0.5-fract(worldPos.xyz);
    #ifdef SWRT_NOISY_PENUMBRAS
    displacementToLight+=penumbraNoise(ditherValue);
    #endif

    if(traceRay(worldPos.xyz,displacementToLight,unitShift,maxSteps)>=0)
        return;

    imageStore(swrtRayHits,(ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)>>1)+ivec2(index*imageSize(swrtRayHits).x/8,0),vec4(1.0,0,0,0));
//    imageStore(colorimg6,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),vec4(color,0));
}