const int debugAxisNum = 5;

bool isVoxelInBounds(vec3 worldPos){
    return worldPos.x>=0 && worldPos.y>=0 && worldPos.z>=0 && worldPos.x<16 && worldPos.y<16 && worldPos.z<16;
}

//in order from 0 to 5, -x,+x,-y,+y,-z,+z
//lsb is 0=neg,1=pos
ivec3 axisNumToVec(uint axis){
    uint upper = axis>>1;
    return ivec3(upper==0,upper==1,upper==2)*(((int(axis)&1)<<1)-1);
}