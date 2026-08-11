#version 430 compatibility

in vec2 texcoord;
#include "/lib/renderComponents/taaAccumulation.glsl"

void main() {
    taaAccumulate();
}