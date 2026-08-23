#version 430

#include "lib/settings.glsl"

#define STAGES 4
#define INDEX_COUNT 4

uniform sampler2D colortex7;
layout (rgba16f) uniform writeonly restrict image2D colorimg13;


uniform sampler2D depthtex1;
#include "/lib/util/conversions.glsl"

#define combine atomicAdd

const float scale = 1048576;
uvec4 getValue(vec2 texcoord){
    vec4 ret;
    ret.rgb = texture(colortex7, texcoord).rgb;
    ret.a=depthToLinear(texture(depthtex1 ,texcoord).x);
    return uvec4(round(ret*scale));
}

void writeValue(ivec2 texpos, uvec4 value){
    imageStore(colorimg13,texpos,value/scale);
}

void correction(inout uvec4 value){
    value>>=2;
}

ivec2 sourceSize(){
    return textureSize(colortex7,0);
}

#include "lib/renderComponents/downsamplePass.glsl"