#version 430
#include "/lib/lighting/floodShadows/fsSeamFill.glsl"

void main(){
    fillSeams(gl_WorkGroupID,gl_LocalInvocationID);
}