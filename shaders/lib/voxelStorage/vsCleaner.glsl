#extension GL_KHR_shader_subgroup_clustered : enable

#define READS_BASE_VOX
#define WRITES_BASE_VOX
#include "/lib/settings.glsl"
#include "/lib/voxelStorage/vsAccess.glsl"


#if VOXELIZATION_MODE==1
uniform mat4 gbufferModelView, gbufferProjection;
uniform vec3 cameraPosition;
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


ivec3 unitShift  = ivec3(0);

uvec4 bitSlices = uvec4(0);

void zeroPosition(ivec3 pos, bool isTop){
    setBaseVoxData(0,pos,unitShift);
}

#define MOVEMENT_TRIM
#include "/lib/util/3dComputeShaderUtils.glsl"

//TODO expiry
#if VOXELIZATION_MODE == 1
bool posOnScreen(ivec3 areaPos){
    vec3 pos = vec3(areaPos-(VOXELIZATION_SIZE>>1))+0.5;
    pos+=unitShift-cameraPosition;
    vec4 clipSpace = gbufferProjection*vec4((gbufferModelView*vec4(pos,1)).xyz,1);
//    clipSpace.w*=1.15;
    clipSpace.rgb/=clipSpace.w;

    return abs(clipSpace.x)<1.0 && abs(clipSpace.y)<1.0 && abs(clipSpace.z)<1.0;
}
#endif

void expire(ivec3 pos){
    bool doExpiry;
    #ifdef DEBUG_NOTHING_EXPIRES
        doExpiry=false;
    #elif (VOXELIZATION_MODE == 1)
        doExpiry=posOnScreen(pos);
    #else
        doExpiry=true;
    #endif

    uint voxel = getBaseVoxData(pos,unitShift);
    int timer = int(voxel>>WORLDVOX_AGE_SHIFT);

    if(doExpiry){
        timer--;
        if(timer>=0){
            voxel-=(1u<<WORLDVOX_AGE_SHIFT);
        }else{
            voxel=0u;
        }
        setBaseVoxData(voxel,pos,unitShift);
    }

    #ifdef QUARTERSIZE_VOXEL_MAP
    uint voxelLayerSlice = subgroupClusteredOr((timer>0?1u:0u)<<(gl_SubgroupInvocationID&0xfu),16u);
    bitSlices[pos.y&3]=voxelLayerSlice;
    if((pos.y&3)==3){
        if((gl_SubgroupInvocationID&0xfu)==0u){
//            setQuarterVoxData(bitSlices,pos,unitShift);
        }
    }
    #endif
}

void main(){
    unitShift = getUnitShift();
    movementTrimSerial(VOXELIZATION_SIZE, unitShift, getPreviousUnitShift());


    if(!shouldCompute(getUpdatePeriod()))
        return;

    ivec3 pos;
    pos.xz=ivec2(gl_SubgroupInvocationID,gl_SubgroupInvocationID>>2)&0x3;

    int sgNum=int(gl_SubgroupInvocationID+gl_SubgroupID*gl_SubgroupSize);
    sgNum= (sgNum>>4)<<2;
    pos.xz+=ivec2((sgNum/SIZE)<<2,sgNum%SIZE);
    pos.xz+=ivec2(gl_WorkGroupSize.xz*gl_WorkGroupID.xz);

    //    pos.xz=ivec2(SIZE*gl_WorkGroupID.xz)+ivec2(gl_LocalInvocationID.xz);

    for(uint i=0;i<SIZE;i++){
        pos.y=int(SIZE*gl_WorkGroupID.y+i);
        expire(pos);
    }
}