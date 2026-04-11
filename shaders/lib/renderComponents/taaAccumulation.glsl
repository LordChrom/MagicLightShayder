#include "/lib/settings.glsl"
uniform int frameCounter;

#include "/lib/util/taaHelper.glsl"

uniform float viewWidth,viewHeight;

uniform sampler2D colortex6;
uniform sampler2D colortex7;

uniform sampler2D colortex10;
uniform sampler2D colortex11;

/* RENDERTARGETS: 10,11 */

layout(location = 0) out vec4 multAccumulation;
layout(location = 1) out vec4 addAccumulation;

void taaAccumulate(){
    ivec2 texpos = ivec2(round(texcoord*vec2(viewWidth,viewHeight)-0.01));
    vec2 jitteredTexcoord = texcoord-jitter();
    ivec2 jitteredTexpos = ivec2(floor((jitteredTexcoord)*scaledScreenDim));


    vec4 multContribution = texture(colortex6,jitteredTexcoord);
    vec4 addContribution = texture(colortex7,jitteredTexcoord);

    vec4 previousMultAccumulation = texelFetch(colortex10,texpos,0);
    vec4 previousAddAccumulation = texelFetch(colortex11,texpos,0);
    float weight = lightSampleWeight(jitteredTexcoord);
    weight*=weight;
    multAccumulation=mix(previousMultAccumulation,multContribution,weight);
    addAccumulation =mix(previousAddAccumulation, addContribution,weight);
}