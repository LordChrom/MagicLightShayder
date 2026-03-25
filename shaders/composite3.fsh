#version 430 compatibility
#include "/lib/renderComponents/blur.glsl"

void main() {
    const vec2 blurDir = vec2(1,0);
    doBlur(blurDir);
}