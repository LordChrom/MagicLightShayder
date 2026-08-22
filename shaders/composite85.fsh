#version 430 compatibility
#include "/lib/settings.glsl"

#define SCALEFACTOR 0x01000000u

#ifdef HALF_RES_DOF
#define DOF_BUCKET_SIZE 64
#else
#define DOF_BUCKET_SIZE 32
#endif

/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outputColor;

layout(std430, binding = 0) readonly restrict buffer ssbo2 {
    uint[][DOF_BUCKET_SIZE][DOF_BUCKET_SIZE][3] outputBuckets;
};
uniform sampler2D colortex0;

uniform float frameTimeCounter;
uniform float viewHeight;
void main(){
    ivec2 samplePos = ivec2(gl_FragCoord.xy);

#ifdef DOF_TEST_PATTERN
    samplePos>>=3;
#endif

    ivec2 bucketPos = samplePos/(DOF_BUCKET_SIZE);
    ivec2 bucketCoord = samplePos%(DOF_BUCKET_SIZE);

    uint bucket = bucketPos.x*int(ceil(viewHeight/DOF_BUCKET_SIZE))+bucketPos.y;

    outputColor=vec3(
        outputBuckets[bucket][bucketCoord.x][bucketCoord.y][0],
        outputBuckets[bucket][bucketCoord.x][bucketCoord.y][1],
        outputBuckets[bucket][bucketCoord.x][bucketCoord.y][2]
    )/float(SCALEFACTOR);


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