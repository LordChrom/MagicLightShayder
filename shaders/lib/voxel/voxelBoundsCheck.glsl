
bool isVoxelInBounds(vec3 worldPos){
    return worldPos.x>=0 && worldPos.y>=0 && worldPos.z>=0 && worldPos.x<16 && worldPos.y<16 && worldPos.z<16;
}