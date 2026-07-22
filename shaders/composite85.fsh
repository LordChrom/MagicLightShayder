#version 430 compatibility
#include "/lib/settings.glsl"

uniform float centerDepthSmooth;

#define MAX_LEVEL 5


in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outputColor;

uniform usampler2D dynamicDofSampler;
uniform sampler2D colortex0;

uniform float frameTimeCounter;
void main(){
    vec3 sampledColor;
    ivec2 samplePos = ivec2(gl_FragCoord.xy);
    #ifdef DOF2_TEST_PATTERN
        samplePos>>=3;
    #endif
//    samplePos = (textureSize(colortex0,0)>>1)+((samplePos-(textureSize(colortex0,0)>>1))>>3);

    ivec2 bufferSize=((textureSize(colortex0,0)>>MAX_LEVEL)+1)<<MAX_LEVEL;

//    samplePos<<=1;
    uvec3 value = uvec3(0);
    ivec2 level;

    //TODO fix locality
    for(level.x=0; level.x<=MAX_LEVEL;level.x++){
        for(level.y=0; level.y<=MAX_LEVEL;level.y++){
            ivec2 levelPos = (samplePos+bufferSize)>>level;
            for(int i=0;i<3;i++){
                #ifdef DOF2_TEST_PATTERN
                if(bool(((level.x+level.y)%7)&(1<<i)))
                    continue;
                #endif
                value[i]+=texelFetch(dynamicDofSampler,ivec2(levelPos.x+i*(bufferSize.x<<1),levelPos.y),0).x;
            }
        }
    }
    sampledColor=value/float(0x00800000u);

    #ifdef DOF2_TEST_PATTERN

    float refColor = 16*fract(frameTimeCounter*0.2);
//    refColor=3;
//    sampledColor*=4*refColor*refColor;
//    sampledColor*=0.5;
    sampledColor*=4e12;

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