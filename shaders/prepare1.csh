#version 430
#include "lib/voxel/voxelSeamFill.glsl"

void main(){
    fillSeams(gl_WorkGroupID,gl_LocalInvocationID);
}