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
    ivec2 samplePos = ivec2(gl_FragCoord.xy);

#ifdef DOF_TEST_PATTERN
    samplePos>>=3;
#endif

    outputColor=vec3(texelFetch(dynamicDofSampler,samplePos,0).rgb)/float(SCALEFACTOR);

#ifdef DOF_TEST_PATTERN
    float refColor;
//        refColor = 64*fract(frameTimeCounter*0.5);
    refColor=30*fract(frameTimeCounter*0.2);

    refColor*=PI*refColor;
//    refColor*=4*refColor;

    outputColor*=0.5*refColor;

    float gridColor = 1;
    const int[] gridlevels = {0,2,5};
    for(int i=0;i<3;i++){
        if (bool((samplePos.x^samplePos.y)&(1<<gridlevels[i])))
            gridColor-=0.3;
    }
    outputColor=mix(outputColor,vec3(gridColor),0.1);
#endif
}