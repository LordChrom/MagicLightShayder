#version 430 compatibility
#include "/lib/settings.glsl"
in vec2 texcoord;

uniform float centerDepthSmooth;
uniform float viewWidth, viewHeight;
uniform mat4 gbufferProjectionInverse;
#include "/lib/util/conversions.glsl"

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;


/* RENDERTARGETS: 6 */
out vec3 CoCbuff;



void main() {
    ivec2 texpos = ivec2(floor(texcoord*vec2(viewWidth,viewHeight)));

    if(texelFetch(depthtex1,texpos,0).x!=texelFetch(depthtex2,texpos,0).x){
        CoCbuff=vec3(0);
        return;
    }
    float rawDepth = texelFetch(depthtex2,texpos,0).x;
    float depthTarget = depthToLinear(centerDepthSmooth);
    float depth = depthToLinear(rawDepth);
    float edgeness = length(vec2(dFdx(depth),dFdy(depth)));
    edgeness=min(edgeness,1);

    depth = 0.6*depth+0.4*distFromCamera(vec3(texcoord,rawDepth));

    const float focalLength = DOF_FOCAL_LENGTH;

    float coc = abs(depth-depthTarget)/depth * (focalLength)/max(0.1,depthTarget-focalLength);
    coc*=DOF_INTENSITY*0.1;

    coc = clamp(abs(coc),0,1);
    coc*=viewHeight;

    CoCbuff=vec3(coc,edgeness,depth);
}