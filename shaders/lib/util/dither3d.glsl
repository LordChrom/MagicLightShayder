uint bayer2u3d(uvec3 pos){
    return ((pos.x&1u)<<2)+((pos.y&1u)<<1)+(pos.z&1u);
}

uint bayer4u3d(uvec3 pos){
    return (bayer2u3d(pos)<<3)|(bayer2u3d(pos>>1));
}

uint getUpdatePeriod(){
    ivec3 centerness = ivec3(gl_WorkGroupID)-(WORK_SIZE>>1)+1;
    centerness=abs(centerness-clamp(centerness,0,1));
    uint distFromCenter = max(max(centerness.x,centerness.y),centerness.z);

    return max(distFromCenter*distFromCenter,1);
}

bool shouldCompute(uint updatePeriod){
    bool shouldCompute = (((bayer4u3d(gl_WorkGroupID)+frameCounter)%updatePeriod)==0);
    return shouldCompute;
}