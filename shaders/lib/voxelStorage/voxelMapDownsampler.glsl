#define READS_SCALING_VOX
#define WRITES_SCALING_VOX
#include "/lib/settings.glsl"
#include "/lib/voxelStorage/vsAccess.glsl"


#if VOXELIZATION_MODE==1
uniform mat4 gbufferModelView, gbufferProjection;
#endif

#define SIZE 8
#define WORK_SIZE VOXELSIZE_SIXTNTH
#define WORK_SIZE_BIGGER VOXELSIZE_3_32NDS

const ivec3 workGroups = ivec3(WORK_SIZE,WORK_SIZE_BIGGER,WORK_SIZE);
layout (local_size_x = SIZE, local_size_y = 1, local_size_z = SIZE) in;

shared uint [SIZE/2][SIZE/2][SIZE/2] higherLevelsBuffer;

ivec3 shift;
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
    uint aEmission = a&WORLDVOX_EMISSION_MASK;
    uint bEmission = b&WORLDVOX_EMISSION_MASK;

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
    ivec3 workGroupBase = ivec3(gl_WorkGroupID*SIZE);

    cascadeLevel=1u;
    ivec3 mipOrigin = ivec3(0);
    do{
        mipOrigin = getScalingVoxOriginPos(cascadeLevel);
        int size = VOXELIZATION_SIZE>>cascadeLevel;
        ivec3 volumeMax = mipOrigin+size;
        if(workGroupBase.x>=mipOrigin.x && workGroupBase.y>=mipOrigin.y && workGroupBase.z>=mipOrigin.z
            &&workGroupBase.x<volumeMax.x && workGroupBase.y<volumeMax.y && workGroupBase.z<volumeMax.z
        ){
            break;
        }
        cascadeLevel++;
        if(cascadeLevel>=NUM_CASCADES)
            return;
    }while(cascadeLevel<NUM_CASCADES);

    workGroupBase-=mipOrigin;

    ivec3 distFromCenter = abs(workGroupBase+((SIZE>>1)-(VOXELIZATION_SIZE>>1)));
    int floodShadowCascade = int(ceil(log2( max(1,
        float(max(max(distFromCenter.x,distFromCenter.y),distFromCenter.z))
        /(AREA_SIZE>>1)
    ))));

    uint updatePeriod = 1<<floodShadowCascade;
    if(!shouldCompute(updatePeriod))
        return;


    ivec3 basePos;
    basePos.xz = ivec2(gl_LocalInvocationID.xz+workGroupBase.xz);

    uint size = VOXELIZATION_SIZE>>cascadeLevel;

    if(basePos.x>=size || basePos.y>=size)
        return;

    shift = getCascadedAreaShift(cascadeLevel-1);

    for(int y=0;y<min(SIZE,size-workGroupBase.y);y++){
        basePos.y = int(y+workGroupBase.y);
        basePos = (basePos<<1)-(shift&1);
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
        basePos=(basePos+1)>>1;
        setScalingVoxData(representative,basePos,cascadeLevel);
    }
}