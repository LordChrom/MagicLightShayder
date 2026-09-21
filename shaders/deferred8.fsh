#version 430
#include "/lib/settings.glsl"
#include "/lib/util/dither.glsl"


in vec2 jitteredTexcoord;

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 voxelLighting;


uniform sampler2D depthtex2;
uniform sampler2D colortex2;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform vec3 cameraPosition;

#include "/lib/lighting/swrt/swrtSampler.glsl"

void main(){

    float solidDepth = texture(depthtex2,jitteredTexcoord).x;
    vec4 normal = texture(colortex2,jitteredTexcoord);
    vec4 worldPosRelative = vec4(jitteredTexcoord,solidDepth,1);


    worldPosRelative.xyz=worldPosRelative.xyz*2-1;
    worldPosRelative = gbufferProjectionInverse*worldPosRelative;
    worldPosRelative/=worldPosRelative.w;
    worldPosRelative.xyz = mat3(gbufferModelViewInverse)*worldPosRelative.xyz+gbufferModelViewInverse[3].xyz;

    float ditherValue = bayer128(ivec2(gl_FragCoord));

    #ifdef SWRT_NOISY_PENUMBRAS
    ditherValue = temporalNoise(ditherValue);
    #endif

    normal.xyz = normalize(normal.xyz*2-1);
    voxelLighting = swrtSample(worldPosRelative.xyz+cameraPosition,normal.xyz, 0f, ditherValue,15u);

    //    imageStore(colorimg6,pos,light);
}