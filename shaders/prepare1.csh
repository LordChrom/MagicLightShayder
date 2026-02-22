#version 430
#include "lib/voxel/voxelSeamFill.glsl"

/*
in uvec3 gl_WorkGroupID;
in uvec3 gl_LocalInvocationID;
in uint  gl_LocalInvocationIndex;
*/

void main(){
    fillSeams(gl_WorkGroupID,gl_LocalInvocationID);
}