#define SECTION_WIDTH 16
#define SECTION_DEPTH 16
#define UPDATE_STRIDE 2

const int debugAxisNum = 5;

bool isVoxelInBounds(vec3 worldPos){
    return worldPos.x>=0 && worldPos.y>=0 && worldPos.z>=0 && worldPos.x<16 && worldPos.y<16 && worldPos.z<16;
}

//in order from 0 to 5, -x,+x,-y,+y,-z,+z
//lsb is 0=neg,1=pos
//returns 0,0,0 when axis out of range
ivec3 axisNumToVec(uint axis){
    uint upper = axis>>1u;
    return ivec3(upper==0,upper==1,upper==2)*(((int(axis)&1)<<1)-1);
}

ivec3 worldPosToSection(vec3 pos, float scale){
    return ivec3(round(pos+scale));
}


ivec3 worldPosToSection(vec3 pos){
    float scale = 0.5;
    return worldPosToSection(pos,0.5);
}

vec3 sectionPosToWorld(ivec3 pos, float scale){
    return vec3(pos)-scale;
}


vec3 sectionPosToWorld(ivec3 pos){
    float scale = 0.5;
    return sectionPosToWorld(pos,0.5);
}



//float distFromSource(vec3 sourcePos, vec3 )