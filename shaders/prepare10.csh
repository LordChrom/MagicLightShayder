#version 430
#include "lib/voxel/voxelLighter.glsl"

/*
in uvec3 gl_WorkGroupID;
in uvec3 gl_LocalInvocationID;
in uint  gl_LocalInvocationIndex;
*/

void main(){
    lightVoxelFaces(gl_WorkGroupID,gl_LocalInvocationID);
}