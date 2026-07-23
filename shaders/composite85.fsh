#version 430 compatibility
#include "/lib/settings.glsl"

#define SCALEFACTOR 0x01000000u

uniform float centerDepthSmooth;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outputColor;

uniform usampler2D dynamicDofSampler;
uniform sampler2D colortex0;

uniform float frameTimeCounter;
void main(){
//    return;
    vec3 sampledColor;
    ivec2 samplePos = ivec2(gl_FragCoord.xy);
    #ifdef DOF2_TEST_PATTERN
        samplePos>>=3;
    #endif
//    samplePos = (textureSize(colortex0,0)>>1)+((samplePos-(textureSize(colortex0,0)>>1))>>3);

//    for(int i=0; i<3; i++){
    sampledColor=vec3(texelFetch(dynamicDofSampler,samplePos,0).rgb)/float(SCALEFACTOR);
//    }

    #ifdef DOF2_TEST_PATTERN

    float refColor = 16*fract(frameTimeCounter*0.2);
//    refColor=3;
//    sampledColor*=4*refColor*refColor;
//    sampledColor*=0.5;
    sampledColor*=4e9;

    float testColor = 1;
    const int[] gridlevels = {0,2,5};
    for(int i=0;i<3;i++){
        if (bool((samplePos.x^samplePos.y)&(1<<gridlevels[i])))
            testColor-=0.3;
    }
            sampledColor=mix(sampledColor,vec3(testColor),0.1);
    #endif
    outputColor = sampledColor;
//    outputColor = vec3(texelFetch(dynamicDofSampler,ivec2(gl_FragCoord.xy),0))/0x00800000;
}