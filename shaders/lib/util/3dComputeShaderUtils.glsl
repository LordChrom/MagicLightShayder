#include "/lib/util/uniforms/frameCounter"
uint bayer2u3d(uvec3 pos){
    return ((pos.x&1u)<<2)+((pos.y&1u)<<1)+(pos.z&1u);
}

uint bayer4u3d(uvec3 pos){
    return (bayer2u3d(pos)<<3)|(bayer2u3d(pos>>1));
}

uint getDistFromCenter(){
    ivec3 centerness = ivec3(gl_WorkGroupID)-(WORK_SIZE>>1)+1;
    centerness=abs(centerness-clamp(centerness,0,1));
    return max(max(centerness.x,centerness.y),centerness.z);
}

uint getUpdatePeriod(){
    uint distFromCenter = getDistFromCenter();
    return max(distFromCenter*distFromCenter,1);
}

bool shouldCompute(uint updatePeriod){
    bool shouldCompute = (((bayer4u3d(gl_WorkGroupID)+frameCounter)%updatePeriod)==0);
    return shouldCompute;
}

#ifdef MOVEMENT_TRIM
bool outOfRegionRange(int pos, int margin, int regionSize){
    return pos<max(0,margin) || pos>=(regionSize+min(0,margin));
}


void movementTrimSerial(int regionSize, ivec3 shift, ivec3 previousShift){
    ivec3 movement = clamp(previousShift-shift,-regionSize,regionSize);
    ivec3 pos;
    pos.xz=ivec2(SIZE*gl_WorkGroupID.xz)+ivec2(gl_LocalInvocationID.xz);
    if(outOfRegionRange(pos.x,movement.x,regionSize) || outOfRegionRange(pos.z,movement.z,regionSize)){
        for(uint i=0;i<SIZE;i++){
            pos.y=int(SIZE*gl_WorkGroupID.y+i);
            zeroPosition(pos,false);
        }
    }

    int wgYOffset = int(SIZE*gl_WorkGroupID.y);
    ivec2 yRange = movement.y>0?
    ivec2(0,max(0,movement.y)-wgYOffset):
    ivec2((regionSize+min(0,movement.y))-wgYOffset,SIZE)
    ;
    yRange.x=max(yRange.x,0);
    yRange.y=min(yRange.y,SIZE);

    bool isTop = movement.y<0;
    for(int i=yRange.x;i<yRange.y;i++){
        pos.y=int(wgYOffset+i);
        zeroPosition(pos, isTop);
    }
}

void movementTrimParallel(int regionSize, ivec3 shift, ivec3 previousShift){
    ivec3 movement = clamp(previousShift-shift,-regionSize,regionSize);
    ivec3 pos = ivec3(gl_LocalInvocationID+SIZE*gl_WorkGroupID);
    if(outOfRegionRange(pos.x,movement.x,regionSize) || outOfRegionRange(pos.y,movement.y,regionSize) || outOfRegionRange(pos.z,movement.z,regionSize)){
        zeroPosition(pos,false);
    }
}
#endif