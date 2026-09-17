#define READS_SCALING_VOX
#define WRITES_SCALING_VOX
#include "/lib/lighting/floodShadows/voxelHelper.glsl"


#if VOXELIZATION_MODE==1
uniform mat4 gbufferModelView, gbufferProjection;
#endif

#define SIZE 8
#define WORK_SIZE VOXELSIZE_SIXTNTH

const ivec3 workGroups = ivec3(WORK_SIZE,WORK_SIZE,WORK_SIZE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = SIZE) in;

uint cascadeLevel;


//void zeroPosition(ivec3 pos){
//    setBaseVoxData(0,pos,shift);
//}

//#define MOVEMENT_TRIM
#include "/lib/util/3dComputeShaderUtils.glsl"


uint getMipSize(){
    return VOXELIZATION_SIZE>>1;
}

uint combineVoxels(uint a, uint b){
    uint aEmission = (a>>WORLDVOX_EMISSION_SHIFT)&0xfu;
    uint bEmission = (b>>WORLDVOX_EMISSION_SHIFT)&0xfu;

    int preferabilityOfA = 0;
    if(aEmission!=bEmission)
        preferabilityOfA+= aEmission>bEmission?8:-8;

    if(bool((a^b)&WORLDVOX_TRANSLUCENT))
        preferabilityOfA+= bool(a&WORLDVOX_TRANSLUCENT)?4:-4;


    if(bool((a^b)&WORLDVOX_OPAQUE))
        preferabilityOfA+= bool(a&WORLDVOX_OPAQUE)?2:-2;

    uint ret = preferabilityOfA>0 ? a : b;
    ret &= ~WORLDVOX_BLOCKAGES_MASK;
    ret |= (a&b)&WORLDVOX_BLOCKAGES_MASK;
    return ret;
}



//no movement trim for now, waiting to abstract that
void main(){
    for(cascadeLevel=1; cascadeLevel<NUM_CASCADES; cascadeLevel++){
        ivec3 basePos = ivec3(gl_LocalInvocationID+(gl_WorkGroupID*SIZE));
        uint size = VOXELIZATION_SIZE>>cascadeLevel;
        if(basePos.x>=size || basePos.y>=size || basePos.z>=size)
            return;
        basePos = (basePos<<1)-(getCascadedAreaShift(cascadeLevel-1)&1);
        uint representative = 0u;
        for(int subPos = 0; subPos<8; subPos++){
            ivec3 localOffset = ivec3(subPos>>2,subPos>>1,subPos)&1;
            uint voxel = getScalingVoxData(basePos+localOffset,cascadeLevel-1);

            uint mask = uint((localOffset.z<<4) | (localOffset.y<<2) | (localOffset.x));
            mask = (mask*3)^0x2au;

            if(bool(subPos))
                representative=combineVoxels(representative,voxel);
            else
                representative=voxel;
        }
        basePos = ivec3(gl_LocalInvocationID+(gl_WorkGroupID*SIZE));
        setScalingVoxData(representative,basePos,cascadeLevel);
    }
}