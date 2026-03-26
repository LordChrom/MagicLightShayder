#version 430 compatibility
//#define FOG_BLUR_SNAPPED

#include "/lib/renderComponents/blur.glsl"


uniform sampler2D colortex7;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

uniform int frameCounter;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 fog;

void main() {
    fog = doFogBlur(colortex7,texcoord,vec2(viewWidth,viewHeight),2);
}