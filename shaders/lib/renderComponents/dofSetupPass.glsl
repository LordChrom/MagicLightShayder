#version 430 compatibility
#include "/lib/util/dofHelper.glsl"
in vec2 texcoord;

uniform float centerDepthSmooth;
uniform float viewWidth, viewHeight;
uniform mat4 gbufferProjectionInverse;
#include "/lib/util/conversions.glsl"

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;


/* RENDERTARGETS: 7 */
layout(location=0) out vec4 CoCbuff;



void main() {
    ivec2 texpos = ivec2(floor(texcoord*vec2(viewWidth,viewHeight)));

    if(texelFetch(depthtex1,texpos,0).x!=texelFetch(depthtex2,texpos,0).x){
        CoCbuff=vec4(1,1,1,0);
        return;
    }

    float depth = depthToLinear(texelFetch(depthtex2,texpos,0).x);
    float depthTarget = depthToLinear(centerDepthSmooth);

    const float focalLength = DOF_FOCAL_LENGTH*1e-3;

    float rad = abs(depth-depthTarget)/depth * (focalLength)/max(0.1,depthTarget-focalLength);

    rad = clamp(abs(rad),0,1);
    rad*=viewHeight;
    rad=clamp(rad,0,DOF_RAD);


    CoCbuff=vec4(0,0,0,rad);
    for(int l=0; l<DOF_PASSES;l++){
        CoCbuff[l]=totalWeightAtOffset(rad,1<<l);
    }
}