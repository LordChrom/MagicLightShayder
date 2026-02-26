#version 430
#include "lib/voxel/voxelSeamFill.glsl"

/*
in uvec3 gl_WorkGroupID;
in uvec3 gl_LocalInvocationID;
in uint  gl_LocalInvocationIndex;
*/



#ifdef AXES_INORDER
const int workGroupZ = 1;
#else
const int workGroupZ = 6;
#endif


layout(std430, binding = 1) restrict buffer indirectDispatches {
    uvec3 dispatches;
} indirectDispatchesAccess;



void main(){
//    if(frameCounter<10)
        indirectDispatchesAccess.dispatches=uvec3(SECTIONS_PER_AREA,NUM_AREAS,workGroupZ);
    fillSeams(gl_WorkGroupID,gl_LocalInvocationID);
}