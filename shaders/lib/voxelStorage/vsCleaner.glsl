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
//bool isPosExpiryExempt(ivec3 areaPos){
//    #if VOXELIZATION_MODE == 1
//    vec3 pos = vec3(areaPos-(AREA_SIZE>>1))*scale+0.5;
//    vec4 clipSpace = gbufferProjection*vec4((gbufferModelView*vec4(pos,1)).xyz,1);
//    clipSpace.w*=1.15;
//
//    return (clipSpace.x<-clipSpace.w || clipSpace.x>clipSpace.w)||
//    (clipSpace.y<-clipSpace.w || clipSpace.y>clipSpace.w)||
//    (clipSpace.z<-clipSpace.w || clipSpace.z>clipSpace.w);
//    #else
//    return false;
//    #endif
//}
//
//void fillVoxSeams(){
//    thisMemOffset = areaOffset(cascadeLevel);
//    upperMemOffset = (cascadeLevel<NUM_CASCADES-1)?areaOffset(cascadeLevel+1):0;
//
//
//
//    ivec3 validHi = min(AREA_SIZE-1-movement,AREA_SIZE-1);
//    ivec3 validLo = max(-movement,0);
//
//    #ifndef DEBUG_NOTHING_EXPIRES
//    //    if(cascadeVisitedThisFrame
//    //        && (posXY.x>=validLo.x && posXY.x<=validHi.x)
//    //        && (posXY.y>=validLo.y && posXY.y<=validHi.y)
//    //    ){
//    //        for (ivec3 areaPos = ivec3(posXY, 0); areaPos.z<AREA_SIZE; areaPos.z++){
//    //            if (isPosExpiryExempt(areaPos) || !(areaPos.z>=validLo.z && areaPos.z<=validHi.z))
//    //                continue;
//    //            uint voxel=getScalingAreaVoxData(areaPos, cascadeLevel);
//    //            voxel-=(uint(bool(voxel))<<WORLDVOX_AGE_SHIFT);
//    //            voxel = bool(voxel&WORLDVOX_AGE_MASK)?voxel:0u;
//    //            setVoxData(voxel, areaPos, thisShift, thisMemOffset);
//    //        }
//    //    }
//    #endif
//
//
//    if(bool(upperMemOffset)&&bool((frameOffset^cascadeLevel)&1u)){
//        //        ivec3 areaPosBase;
//        //        areaPosBase.xz = posXY&~1;
//        //        areaPosBase.y= ((((posXY.x&1)<<1)+posXY.y&1)<<1);
//        //        for(int j=AREA_SIZE/8;j>=0;j--){
//        //            ivec3 areaPos = ivec3(areaPosBase.x,(areaPosBase.y&7)|(j<<3),areaPosBase.z);
//        //            if(areaPos.y<0 || areaPos.y>=AREA_SIZE) continue;
//        //
//        //            ivec3 upperAreaPos = upperCascadeAreaPosForSeamFiller(areaPos,thisShift);
//        //
//        //            if(areaPos.x<validLo.x || areaPos.y<validLo.y || areaPos.z<validLo.z)
//        //                continue;
//        //
//        //            if(voxelIsSplit(upperAreaPos,upperShift, cascadeLevel+1))
//        //                continue;
//        //
//        //            uint representative = 0;
//        //            for(int i=0; i<8; i++){
//        //                ivec3 subPos = (ivec3(i,i>>1,i>>2)&1)+areaPos;
//        //                if(subPos.x>validHi.x || subPos.y>validHi.y || subPos.z>validHi.z)
//        //                    continue;
//        //                uint sampledVox = getVoxData(subPos, thisShift, thisMemOffset);
//        //                if((sampledVox>>WORLDVOX_AGE_SHIFT)<=2) continue;
//        //                representative = max(representative,sampledVox&~WORLDVOX_AGE_MASK);
//        //            }
//        //
//        //            representative = representative | uint(WORLDVOX_INITIAL_TIME<<WORLDVOX_AGE_SHIFT);
//        //            updateVoxData(representative, upperAreaPos, upperShift, upperMemOffset);
//        //        }
//    }
//}

void main(){
    shift = getUnitShift();
    movementTrim(VOXELIZATION_SIZE, shift, getPreviousUnitShift());
}