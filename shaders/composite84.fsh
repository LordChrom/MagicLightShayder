#version 430 compatibility
#include "/lib/settings.glsl"

uniform float viewHeight;

// cost is  O(n^2) rad, O((4^n)/(5-n)) quality


uniform sampler2D depthtex1, depthtex2;
uniform float centerDepthSmooth;

#include "/lib/util/conversions.glsl"

#ifdef DOF2_TEST_PATTERN
/* RENDERTARGETS: 12,0 */
layout(location=1) out vec3 testColor;
#else
/* RENDERTARGETS: 12 */
#endif
layout(location=0) out vec2 CoCbuff;

float calcRadius(ivec2 texpos){
    if(texelFetch(depthtex1,texpos,0).x!=texelFetch(depthtex2,texpos,0).x){
        return 0;
    }
    float depth = depthToLinear(texelFetch(depthtex2,texpos,0).x);
    float depthTarget = depthToLinear(centerDepthSmooth);

    const float focalLength = DOF_FOCAL_LENGTH*1e-3;

    float rad = abs(depth-depthTarget)/depth * (focalLength)/max(0.1,depthTarget-focalLength);

    rad = clamp(abs(rad),0,1);
    rad*=viewHeight;
    return clamp(rad,0,32)*sign(depth-depthTarget);
}




in vec2 texcoord;



void main() {
    ivec2 texpos = ivec2(gl_FragCoord.xy);

    #ifdef DOF2_TEST_PATTERN
    testColor=vec3(0);
    CoCbuff.y=0;

    bool awa = (texpos%29)==ivec2(0);
    if(awa){
        CoCbuff.y=6.19;
        testColor=vec3(1);
    }
    #else
    CoCbuff.y=calcRadius(texpos);
    #endif
    CoCbuff.y=clamp(abs(CoCbuff.y),0,32);
}