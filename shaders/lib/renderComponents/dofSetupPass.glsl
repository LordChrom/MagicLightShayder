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


#if DOF_LEVEL>1
/* RENDERTARGETS: 6,7 */
layout(location=1) out vec4 weightTotalsBuff;
#else
/* RENDERTARGETS: 6 */
#endif
layout(location=0) out vec3 CoCbuff;



void main() {
    ivec2 texpos = ivec2(floor(texcoord*vec2(viewWidth,viewHeight)));

    if(texelFetch(depthtex1,texpos,0).x!=texelFetch(depthtex2,texpos,0).x){
        CoCbuff=vec3(0,0,1);
        #if DOF_LEVEL>1
            weightTotalsBuff=vec4(1);
        #endif
        return;
    }

    float rawDepth = texelFetch(depthtex2,texpos,0).x;
    float depthTarget = depthToLinear(centerDepthSmooth);
    float depth = depthToLinear(rawDepth);

    const float focalLength = DOF_FOCAL_LENGTH;

    float rad = abs(depth-depthTarget)/depth * (focalLength)/max(0.1,depthTarget-focalLength);
    rad*=DOF_INTENSITY*0.1;

    rad = clamp(abs(rad),0,1);
    rad*=viewHeight;


    vec4 weights=vec4(0);
    for(int l=0; l<DOF_LEVEL;l++){
        weights[l]=totalWeightAtOffset(rad,dFromLevel(l));
    }

    #if DOF_LEVEL>1
        weightTotalsBuff=weights;
        CoCbuff=vec3(rad,depth,0);
    #else
        CoCbuff=vec3(rad,depth,weights[0]);
    #endif


}