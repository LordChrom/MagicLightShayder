#version 430

#define PASS_DISABLED
#include "lib/settings.glsl"

#define STAGES 4
#define INDEX_COUNT 1

uniform sampler2D colortex7;
layout (r32f) uniform writeonly restrict image2D colorimg12;


uniform sampler2D depthtex2;
#include "/lib/util/conversions.glsl"

#define combine atomicMin

const float scale = 0x40000000;
uint getValue(vec2 texcoord){
    float depth = texture(depthtex2, texcoord).x;
    return uint(round(depth*scale));
}

void writeValue(ivec2 texpos, uint value){
    imageStore(colorimg12,texpos,vec4(value/scale,0,0,0));
}

void correction(inout uint value){
//    value>>=2;
}

ivec2 sourceSize(){
    return textureSize(depthtex2,0);
}

#include "lib/renderComponents/downsamplePass.glsl"