#ifdef CASCADED_SHADOWS
const int perLevelScale = 4;
int getMaxLevel(vec2 pos){
    float maxDist = max(abs(pos.x),abs(pos.y))*1.1;
    maxDist=1/max(0.001,maxDist);
//    return int(log2(maxDist)/log2(perLevelScale));
    return int(log2(maxDist)*0.5);
}

vec2 levelDistort(vec2 shadowpos, int level){
    vec2 levelCenter = vec2(level>>1,level&1)-0.5;
    int levelScale = 1<<(level+level);
    return clamp(shadowpos*0.5*levelScale,-0.5,0.5)+levelCenter;
}
vec2 distort(vec2 shadowpos){
    if(shadowpos.x<-1 || shadowpos.y<-1 || shadowpos.x>1 || shadowpos.y>1)
        return vec2(-100);
    return levelDistort(shadowpos,clamp(getMaxLevel(shadowpos*1.01),0,3));
}
#else
vec2 distort(vec2 shadowpos){
    float distortFactor = 1/(0.1+max(length(shadowpos),0.05));
    return vec2(shadowpos.xy*distortFactor);
}
#endif

float distortZ(float z){
    return 0.5*z;
}

vec3 distort(vec3 shadowpos){
    return vec3(distort(shadowpos.xy),distortZ(shadowpos.z));
}