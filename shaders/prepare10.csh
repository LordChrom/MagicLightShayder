#version 430
#define LIGHTER_PASS 0
#include "lib/voxel/voxelLighter.glsl"

void main(){
    #if LIGHTER_PASS<LIGHTING_SYSTEM_PASSES
    lightVoxelFaces(gl_WorkGroupID,gl_LocalInvocationID);
    #endif
}