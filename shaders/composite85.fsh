#version 430 compatibility
#include "/lib/settings.glsl"

uniform float centerDepthSmooth;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outputColor;

uniform usampler2D dynamicDofSampler;

void main(){
    vec3 sampledColor;
    ivec2 samplePos = ivec2(gl_FragCoord.xy);
    samplePos.x*=3;
    for(int i=0; i<3; i++){
        sampledColor[i]=float(texelFetch(dynamicDofSampler,ivec2(samplePos.x+i,samplePos.y),0).x)/float(0x00800000u);
    }

    outputColor = sampledColor;
//    outputColor = vec3(texelFetch(dynamicDofSampler,ivec2(gl_FragCoord.xy),0))/0x00800000;
}