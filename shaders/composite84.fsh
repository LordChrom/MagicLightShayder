#version 430 compatibility
#include "/lib/settings.glsl"

uniform float viewHeight;

// cost is  O(n^2) rad, O((4^n)/(5-n)) quality


uniform sampler2D depthtex1, depthtex2;
uniform float centerDepthSmooth;

#include "/lib/util/conversions.glsl"

/* RENDERTARGETS: 12 */
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
    return clamp(rad,0,DOF_RAD)*sign(depth-depthTarget);
}




in vec2 texcoord;



void main() {
    ivec2 texpos = ivec2(gl_FragCoord.xy);
    CoCbuff.y=calcRadius(texpos);
    CoCbuff.y=clamp(abs(CoCbuff.y),1,10);
}