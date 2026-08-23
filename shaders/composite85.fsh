#version 430 compatibility
#include "/lib/settings.glsl"

#define SCALEFACTOR 0x01000000u


/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outputColor;


uniform sampler2D colortex14;

#ifdef HALF_RES_DOF
uniform sampler2D colortex12;
#endif

uniform sampler2D colortex0;

uniform float frameTimeCounter;
uniform float viewHeight;
void main(){
    ivec2 samplePos = ivec2(gl_FragCoord.xy);

#ifdef DOF_TEST_PATTERN
    samplePos>>=3;
#endif
    #ifdef HALF_RES_DOF
    float radius = texelFetch(colortex12,samplePos,0).y;
    outputColor=texture(colortex14,(0.5*vec2(samplePos)-0.5)/textureSize(colortex14,0),0).rgb;
    if(radius<=0.5){
        outputColor+=texelFetch(colortex0,samplePos,0).rgb;
    }
    #else
    outputColor=texelFetch(colortex14,samplePos,0).rgb;
    #endif



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