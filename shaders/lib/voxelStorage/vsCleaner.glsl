#define READS_BASE_VOX
#define WRITES_BASE_VOX
#include "/lib/settings.glsl"
#include "/lib/voxelStorage/vsAccess.glsl"


#if VOXELIZATION_MODE==1
uniform mat4 gbufferModelView, gbufferProjection;
#endif

#define SIZE 16


#if SIZE==8
    #define WORK_SIZE VOXELSIZE_EIGTH
#else
    #define SIZE 16
    #define WORK_SIZE VOXELSIZE_SIXTNTH
#endif

const ivec3 workGroups = ivec3(WORK_SIZE,WORK_SIZE,WORK_SIZE);
layout (local_size_x = SIZE, local_size_y = 1, local_size_z = SIZE) in;


ivec3 shift  = ivec3(0);

void zeroPosition(ivec3 pos, bool isTop){
    setBaseVoxData(0,pos,shift);
}

#define MOVEMENT_TRIM
#include "/lib/util/3dComputeShaderUtils.glsl"

//TODO expiry
bool isPosExpiryExempt(ivec3 areaPos){
    #if VOXELIZATION_MODE == 1
    vec3 pos = vec3(areaPos-(VOXELIZATION_SIZE>>1))+0.5;
    vec4 clipSpace = gbufferProjection*vec4((gbufferModelView*vec4(pos,1)).xyz,1);
    clipSpace.w*=1.15;

    return (clipSpace.x<-clipSpace.w || clipSpace.x>clipSpace.w)||
    (clipSpace.y<-clipSpace.w || clipSpace.y>clipSpace.w)||
    (clipSpace.z<-clipSpace.w || clipSpace.z>clipSpace.w);
    #else
    return false;
    #endif
}

void expire(ivec3 pos){
    if(isPosExpiryExempt(pos))
        return;
    uint voxel = getBaseVoxData(pos,shift);
    int timer = int(voxel>>WORLDVOX_AGE_SHIFT);
    timer--;
    if(timer>=0){
        voxel-=(1u<<WORLDVOX_AGE_SHIFT);
    }else{
        voxel=0u;
    }
    setBaseVoxData(voxel,pos,shift);

}

void main(){
    shift = getUnitShift();
    movementTrimSerial(VOXELIZATION_SIZE, shift, getPreviousUnitShift());


    if(!shouldCompute(getUpdatePeriod()))
        return;

    ivec3 pos;
    pos.xz=ivec2(SIZE*gl_WorkGroupID.xz)+ivec2(gl_LocalInvocationID.xz);

    for(uint i=0;i<SIZE;i++){
        pos.y=int(SIZE*gl_WorkGroupID.y+i);
        expire(pos);
    }

}