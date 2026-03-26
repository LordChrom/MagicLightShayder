#version 430 compatibility
#include "/lib/renderComponents/blur.glsl"


uniform sampler2D colortex6;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 lighting;

void main() {
    if(texcoord.x>LIGHTING_RENDERSCALE || texcoord.y>LIGHTING_RENDERSCALE) return;
    vec2 pxStep = 2.0/vec2(viewWidth,viewHeight);

    lighting = doBlur(colortex6, texcoord,pxStep,7,3,2);
}