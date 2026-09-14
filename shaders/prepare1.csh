#version 430
#include "/lib/lighting/floodShadows/voxelSeamFill.glsl"

void main(){
    fillSeams(gl_WorkGroupID,gl_LocalInvocationID);
}