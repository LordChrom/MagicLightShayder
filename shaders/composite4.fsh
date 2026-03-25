#version 430 compatibility
#include "/lib/renderComponents/blur.glsl"
//
//uniform sampler2D colortex6;
//
//in vec2 texcoord;
//
//
///* RENDERTARGETS: 6,7 */
//layout(location = 0) out vec4 lighting;

void main() {
    const vec2 blurDir = vec2(0,1);
    doBlur(blurDir);
//    lighting = texture(colortex6,texcoord);

}