#version 430
#define LIGHTER_PASS 2
#include "lib/voxel/voxelLighter.glsl"

void main(){
    #if LIGHTER_PASS<CONSECUTIVE_WAVES
    lightVoxelFaces(gl_WorkGroupID,gl_LocalInvocationID);
    #endif
}