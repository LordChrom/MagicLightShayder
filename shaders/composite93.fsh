#version 430 compatibility

#define PASS 4

uniform float viewWidth, viewHeight;
in vec2 texcoord;

#include "/lib/renderComponents/dof.glsl"

/* RENDERTARGETS: 0 */
out vec3 colorOut;

void main() {
    ivec2 texpos = ivec2(floor(texcoord*vec2(viewWidth,viewHeight)));
    colorOut = dofBlur(texpos, PASS);
}