#version 430
#include "/lib/settings.glsl"
#include "/lib/util/dither.glsl"


//in vec2 jitteredTexcoord;

///* RENDERTARGETS: 6 */
//layout(location = 0) out vec4 voxelLighting;

#define SIZE 16
const vec2 workGroupsRender = vec2(LIGHTING_RENDERSCALE,LIGHTING_RENDERSCALE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;
layout (rgba16f) uniform writeonly restrict image2D colorimg6;

uniform sampler2D depthtex2;
uniform sampler2D colortex2;

uniform vec2 scaledScreenDim;
uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform vec3 cameraPosition;

#include "/lib/lighting/swrt/swrtSampler.glsl"

void main(){

    vec2 jitteredTexcoord = (vec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)+0.5)/scaledScreenDim;
    float solidDepth = texture(depthtex2,jitteredTexcoord).x;
    vec4 normal = texture(colortex2,jitteredTexcoord);
    vec4 worldPosRelative = vec4(jitteredTexcoord,solidDepth,1);


    worldPosRelative.xyz=worldPosRelative.xyz*2-1;
    worldPosRelative = gbufferProjectionInverse*worldPosRelative;
    worldPosRelative/=worldPosRelative.w;
    worldPosRelative.xyz = mat3(gbufferModelViewInverse)*worldPosRelative.xyz+gbufferModelViewInverse[3].xyz;

    float ditherValue = bayer128(ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy));

    #ifdef SWRT_NOISY_PENUMBRAS
    ditherValue = temporalNoise(ditherValue);
    #endif

    normal.xyz = normalize(normal.xyz*2-1);
    vec4 voxelLighting = swrtSample(worldPosRelative.xyz+cameraPosition,normal.xyz, 0f, ditherValue,15u);

    imageStore(colorimg6,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),voxelLighting);
}