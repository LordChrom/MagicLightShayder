#include "/lib/settings.glsl"
#define WRITES_LIGHT_LIST
#include "/lib/voxelStorage/vsAccess.glsl"
#include "/lib/lighting/swrt/lightListAccess.glsl"

ivec3 unitShift = ivec3(0);


#define SIZE 16
#define WORK_SIZE VOXELSIZE_SIXTNTH

const ivec3 workGroups = ivec3(WORK_SIZE,WORK_SIZE,WORK_SIZE);
layout (local_size_x = SIZE, local_size_y = 1, local_size_z = SIZE) in;

void zeroPosition(ivec3 pos, bool isTop){
    clearLightList(pos, unitShift);
}

#define MOVEMENT_TRIM
#include "/lib/util/3dComputeShaderUtils.glsl"

void main(){
    unitShift = getUnitShift();
    //TODO make another movement trim for dedicated trimmer passes.
    movementTrimSerial(VOXELIZATION_SIZE, unitShift, getPreviousUnitShift());
}