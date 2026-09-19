#ifndef VOXEL_MAP_ACCESS_GLSL
#define VOXEL_MAP_ACCESS_GLSL
#include "/lib/voxelStorage/volumeShifting.glsl"

uint modVoxelizationSize(uint x){
    #if (VOXELIZATION_SIZE&(VOXELIZATION_SIZE-1))
    return (x+0x10000u*VOXELIZATION_SIZE)%VOXELIZATION_SIZE;
    #else
    return x&uint(VOXELIZATION_SIZE-1);
    #endif
}
uvec2 modVoxelizationSize(uvec2 x){
    #if (VOXELIZATION_SIZE&(VOXELIZATION_SIZE-1))
    return (x+0x10000u*VOXELIZATION_SIZE)%VOXELIZATION_SIZE;
    #else
    return x&uint(VOXELIZATION_SIZE-1);
    #endif
}
uvec3 modVoxelizationSize(uvec3 x){
    #if (VOXELIZATION_SIZE&(VOXELIZATION_SIZE-1))
    return (x+0x10000u*VOXELIZATION_SIZE)%VOXELIZATION_SIZE;
    #else
    return x&uint(VOXELIZATION_SIZE-1);
    #endif
}
int modVoxelizationSize(int x){ return int(modVoxelizationSize(uint(x)));}
ivec2 modVoxelizationSize(ivec2 x){ return ivec2(modVoxelizationSize(uvec2(x)));}
ivec3 modVoxelizationSize(ivec3 x){ return ivec3(modVoxelizationSize(uvec3(x)));}

#ifdef READS_SCALING_VOX
#define READS_BASE_VOX
#endif

#if defined WRITES_BASE_VOX && defined CHANGE_TRACKING
#define WRITES_CHANGE_VOX
#endif

#if defined READS_CHANGE_VOX || defined WRITES_CHANGE_VOX
layout (r8ui) uniform restrict
#ifndef WRITES_CHANGE_VOX
readonly
#endif
uimage3D changeVox;
#endif

#ifdef WRITES_CHANGE_VOX
void setChangeTime(uint timer, ivec3 sectionPos){
    sectionPos = modVoxelizationSize((sectionPos+getAreaShift(16.0))<<4)>>4;
    imageStore(changeVox,sectionPos,uvec4(timer,0,0,0));
}

void clearChangeTime(ivec3 sectionPos){
    setChangeTime(0, sectionPos);
}
#endif

#ifdef READS_CHANGE_VOX
uint getChangeTime(ivec3 sectionPos){
    sectionPos = modVoxelizationSize((sectionPos+getAreaShift(16.0))<<4)>>4;
    return imageLoad(changeVox,sectionPos).x;
}
#endif




#if defined READS_BASE_VOX || defined WRITES_BASE_VOX
layout (r32ui) uniform restrict
#ifndef WRITES_BASE_VOX
readonly
#endif
uimage3D baseWorldVox;
#endif

#ifdef READS_BASE_VOX
uint getBaseVoxData(ivec3 areaPos, ivec3 areaShift){
    areaPos=clamp(areaPos,0,VOXELIZATION_SIZE-1);
    areaPos = modVoxelizationSize(areaPos+areaShift);
    return imageLoad(baseWorldVox,areaPos).x;
}
#endif


#ifdef WRITES_BASE_VOX
void setBaseVoxData(uint packedData, ivec3 areaPos, ivec3 areaShift){
    if(areaPos.x<0 || areaPos.y<0 || areaPos.z<0
        || areaPos.x>=VOXELIZATION_SIZE || areaPos.y>=VOXELIZATION_SIZE || areaPos.z>=VOXELIZATION_SIZE
    ){
        return;
    }

    ivec3 memPos = modVoxelizationSize(areaPos+areaShift);
    #ifdef CHANGE_TRACKING
    uint oldData = imageLoad(baseWorldVox,memPos).x;
    if(bool((oldData^packedData)&~WORLDVOX_AGE_MASK)){
    #endif
        imageStore(baseWorldVox,memPos,uvec4(packedData,0,0,0));
    #ifdef CHANGE_TRACKING

        clearChangeTime((areaPos+(areaShift&0xf))>>4);
    }
    #endif
}
#endif



ivec3 getScalingVoxOriginPos(uint cascade){
    if(cascade<=1)
        return ivec3(0);
    return ivec3(VOXELSIZE_HALF-(VOXELSIZE_HALF>>(cascade-2)),VOXELSIZE_HALF,0);
}

#if defined READS_SCALING_VOX || defined WRITES_SCALING_VOX
layout (r32ui) uniform restrict
#ifndef WRITES_SCALING_VOX
readonly
#endif
#ifndef READS_SCALING_VOX
writeonly
#endif
uimage3D scalingWorldVox;
#endif

#ifdef READS_SCALING_VOX
uint getScalingVoxData(ivec3 pos, uint cascade){
    ivec3 shift = getCascadedAreaShift(cascade);

    if(cascade==0)
    return getBaseVoxData(pos,shift);

    uint size = VOXELIZATION_SIZE>>cascade;
    pos=clamp(pos,0,int(size)-1);

    pos +=shift;
    pos = modVoxelizationSize(pos<<cascade)>>cascade;
    pos +=getScalingVoxOriginPos(cascade);

    return imageLoad(scalingWorldVox,pos).x;
}

uint getScalingAreaVoxData(ivec3 areaPos, uint cascade){
    areaPos += ((VOXELIZATION_SIZE>>cascade)-AREA_SIZE)>>1;
    return getScalingVoxData(areaPos,cascade);
}
#endif


#ifdef WRITES_SCALING_VOX
void setScalingVoxData(uint packedData, ivec3 pos, uint cascade){
    if(cascade==0) return;

    uint size = VOXELIZATION_SIZE>>cascade;

    if(pos.x<0 || pos.y<0 || pos.z<0
        || pos.x>=size || pos.y>=size || pos.z>= size)
    return;


    pos +=getCascadedAreaShift(cascade);
    pos = modVoxelizationSize(pos<<cascade)>>cascade;
    pos +=getScalingVoxOriginPos(cascade);

    imageStore(scalingWorldVox,pos,uvec4(packedData,0,0,0));
}
#endif

#endif