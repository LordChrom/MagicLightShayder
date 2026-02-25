#version 430
#include "lib/voxel/voxelSeamFill.glsl"

/*
in uvec3 gl_WorkGroupID;
in uvec3 gl_LocalInvocationID;
in uint  gl_LocalInvocationIndex;
*/

//uniform int frameCounter;


layout(std430, binding = 1) restrict buffer indirectDispatches {
    uvec3 dispatches;
} indirectDispatchesAccess;

void main(){
    if(frameCounter<10)
        indirectDispatchesAccess.dispatches=ivec3(SECTIONS_PER_ZONE,NUM_ZONES,1);
    fillSeams(gl_WorkGroupID,gl_LocalInvocationID);
}