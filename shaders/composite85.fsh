#version 430 compatibility
#include "/lib/settings.glsl"

uniform float centerDepthSmooth;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outputColor;

uniform usampler2D dynamicDofSampler;
uniform sampler2D colortex0;

void main(){
    vec3 sampledColor;
    ivec2 samplePos = ivec2(gl_FragCoord.xy);
    #ifdef DOF2_TEST_PATTERN
        samplePos>>=3;
    #endif

    uint pageSize = textureSize(colortex0,0).x;
    for(int i=0; i<3; i++){
        sampledColor[i]=float(texelFetch(dynamicDofSampler,ivec2(samplePos.x+i*pageSize,samplePos.y),0).x)/float(0x00800000u);
    }

    #ifdef DOF2_TEST_PATTERN
    float testColor = 1;
    for(int i=0;i<=2;i+=2){
        if (bool((samplePos.x^samplePos.y)&(1<<i)))
            testColor-=0.3;
    }
            sampledColor=mix(sampledColor,vec3(testColor),0.1);
    #endif
    outputColor = sampledColor;
//    outputColor = vec3(texelFetch(dynamicDofSampler,ivec2(gl_FragCoord.xy),0))/0x00800000;
}