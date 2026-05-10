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
    float depthTarget = depthToLinear(centerDepthSmooth);
    float depth = texelFetch(depthtex0,texpos,0).x;
//    depth = distFromCamera(vec3(texcoord,depth));
//    depth = depthToLinear(depth);

    depth = 0.4*distFromCamera(vec3(texcoord,depth))+0.6*depthToLinear(depth);

    const float focalLength = DOF_FOCAL_LENGTH;

    float coc = abs(depth-depthTarget) * (focalLength)/max(0.1,depthTarget-focalLength);
    coc*=DOF_INTENSITY*viewHeight;
    coc = abs(coc);

    CoCbuff=vec3(coc);
}