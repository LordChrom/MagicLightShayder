#version 430 compatibility
#include "/lib/settings.glsl"

uniform float viewHeight;

// cost is  O(n^2) rad, O((4^n)/(5-n)) quality


uniform sampler2D depthtex0, depthtex1, depthtex2;
uniform float centerDepthSmooth;

#include "/lib/util/conversions.glsl"

#ifdef DOF_TEST_PATTERN
/* RENDERTARGETS: 12,0 */
layout(location=1) out vec3 testColor;
#else
/* RENDERTARGETS: 12 */
#endif
layout(location=0) out vec2 CoCbuff;


#ifdef HALF_RES_DOF
layout(std430, binding = 2) writeonly restrict buffer ssbo2 {
    uint[][DOF_BUCKET_SIZE][DOF_BUCKET_SIZE][3] outputBuckets;
};
#endif

float calcRadius(ivec2 texpos){
    if(texelFetch(depthtex1,texpos,0).x!=texelFetch(depthtex2,texpos,0).x){
        return 0;
    }
    float solidDepth =  depthToLinear(texelFetch(depthtex1,texpos,0).x);
    float transDepth =  depthToLinear(texelFetch(depthtex0,texpos,0).x);
    float depthTarget = depthToLinear(centerDepthSmooth);

    const float focalLength = DOF_FOCAL_LENGTH*1e-3;

    float focalFactor = (focalLength)/max(0.1,depthTarget-focalLength);
    float solidRad = abs(solidDepth-depthTarget)/solidDepth * focalFactor;
    float transRad = abs(transDepth-depthTarget)/transDepth * focalFactor;

    float rad = (solidRad+transRad)*0.5;

    rad = clamp(abs(rad),0,1);
    rad*=viewHeight;
    return max(rad,0)*sign(solidDepth+transDepth-2*depthTarget);
}




in vec2 texcoord;

uniform float frameTimeCounter;

void main() {
    ivec2 texpos = ivec2(gl_FragCoord.xy);

    #ifdef HALF_RES_DOF
    ivec2 bucketPos = texpos/(DOF_BUCKET_SIZE);
    ivec2 bucketCoord = texpos%(DOF_BUCKET_SIZE);

    uint bucket = bucketPos.x*int(ceil(viewHeight/DOF_BUCKET_SIZE))+bucketPos.y;

    outputBuckets[bucket][bucketCoord.x][bucketCoord.y][0]=0u;
    outputBuckets[bucket][bucketCoord.x][bucketCoord.y][1]=0u;
    outputBuckets[bucket][bucketCoord.x][bucketCoord.y][2]=0u;
    #endif

    #ifdef DOF_TEST_PATTERN
    testColor=vec3(0);
    CoCbuff.y=0;

    bool awa = (texpos%61)==ivec2(0);
    if(awa){
        CoCbuff.y=30*fract(frameTimeCounter*0.2);
//        CoCbuff.y=3;
        testColor=vec3(1);
    }
    #else
    CoCbuff.y=calcRadius(texpos);
    #endif
    CoCbuff.y=clamp(abs(CoCbuff.y),0,256);
}