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

    uint sampleCascade = cascadeLevel-1;
    shift = getCascadedAreaShift(sampleCascade);
    ivec3 truePosLo, truePosHi;

    truePosLo.xz = (basePos.xz<<1)+(shift.xz&~1);
    truePosHi.xz = truePosLo.xz+1;

    ivec3 sampleMipOrigin = getScalingVoxOriginPos(sampleCascade);
    truePosLo.xz = (modVoxelizationSize(truePosLo.xz<<sampleCascade)>>sampleCascade)+sampleMipOrigin.xz;
    truePosHi.xz = (modVoxelizationSize(truePosHi.xz<<sampleCascade)>>sampleCascade)+sampleMipOrigin.xz;


    for(int y=0;y<min(SIZE,size-workGroupBase.y);y++){
        basePos.y = int(y+workGroupBase.y);
        truePosLo.y = (basePos.y<<1)+(shift.y&~1);
        truePosHi.y = truePosLo.y+1;
        truePosLo.y = (modVoxelizationSize(truePosLo.y<<sampleCascade)>>sampleCascade)+sampleMipOrigin.y;
        truePosHi.y = (modVoxelizationSize(truePosHi.y<<sampleCascade)>>sampleCascade)+sampleMipOrigin.y;

        uint[8] samples;

        if(sampleCascade==0){
            samples[0] = imageLoad(baseWorldVox,ivec3(truePosLo.x,truePosLo.y,truePosLo.z)).x;
            samples[1] = imageLoad(baseWorldVox,ivec3(truePosLo.x,truePosLo.y,truePosHi.z)).x;
            samples[2] = imageLoad(baseWorldVox,ivec3(truePosLo.x,truePosHi.y,truePosLo.z)).x;
            samples[3] = imageLoad(baseWorldVox,ivec3(truePosLo.x,truePosHi.y,truePosHi.z)).x;
            samples[4] = imageLoad(baseWorldVox,ivec3(truePosHi.x,truePosLo.y,truePosLo.z)).x;
            samples[5] = imageLoad(baseWorldVox,ivec3(truePosHi.x,truePosLo.y,truePosHi.z)).x;
            samples[6] = imageLoad(baseWorldVox,ivec3(truePosHi.x,truePosHi.y,truePosLo.z)).x;
            samples[7] = imageLoad(baseWorldVox,ivec3(truePosHi.x,truePosHi.y,truePosHi.z)).x;
        }else{
            samples[0] = imageLoad(scalingWorldVox,ivec3(truePosLo.x,truePosLo.y,truePosLo.z)).x;
            samples[1] = imageLoad(scalingWorldVox,ivec3(truePosLo.x,truePosLo.y,truePosHi.z)).x;
            samples[2] = imageLoad(scalingWorldVox,ivec3(truePosLo.x,truePosHi.y,truePosLo.z)).x;
            samples[3] = imageLoad(scalingWorldVox,ivec3(truePosLo.x,truePosHi.y,truePosHi.z)).x;
            samples[4] = imageLoad(scalingWorldVox,ivec3(truePosHi.x,truePosLo.y,truePosLo.z)).x;
            samples[5] = imageLoad(scalingWorldVox,ivec3(truePosHi.x,truePosLo.y,truePosHi.z)).x;
            samples[6] = imageLoad(scalingWorldVox,ivec3(truePosHi.x,truePosHi.y,truePosLo.z)).x;
            samples[7] = imageLoad(scalingWorldVox,ivec3(truePosHi.x,truePosHi.y,truePosHi.z)).x;
        }

        uint representative = samples[0];
        for(int i=1;i<8;i++){
            representative = combineVoxels(representative,samples[i]);
        }
        setScalingVoxData(representative,basePos,cascadeLevel);
    }
}