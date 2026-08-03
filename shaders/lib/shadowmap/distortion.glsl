float distortZ(float z){
    return 0.5*z;
}

#ifdef CASCADED_SHADOWS
const float perLevelScale = 4;
float getFloatMaxLevel(vec2 pos){
    float maxDist = max(abs(pos.x),abs(pos.y))*1.1;
    maxDist=1/max(0.001,maxDist);
    const float returnMul = log2(perLevelScale);
    return log2(maxDist)/returnMul;
}
int getMaxLevel(vec2 pos){
    return int(getFloatMaxLevel(pos));
}

vec2 levelDistort(vec2 shadowpos, int level){
    vec2 levelCenter = vec2(level>>1,level&1)-0.5;
    float levelScale=bool(level&2)? perLevelScale*perLevelScale : 1;
    if(bool(level&1))
        levelScale*=perLevelScale;
    return clamp(shadowpos*0.5*levelScale,-0.5,0.5)+levelCenter;
}
vec2 levelDistortAndReport(vec2 shadowpos, int level, out bool oob){
    vec2 levelCenter = vec2(level>>1,level&1)-0.5;
    float levelScale=bool(level&2)? perLevelScale*perLevelScale : 1;
    if(bool(level&1))
    levelScale*=perLevelScale;
    shadowpos*=levelScale;
    oob = shadowpos.x<-1 || shadowpos.y<-1 || shadowpos.x>1 || shadowpos.y>1;
    shadowpos = clamp(shadowpos,-1,1);
    return shadowpos*0.5+levelCenter;
}
vec2 distort(vec2 shadowpos){
    if(shadowpos.x<-1 || shadowpos.y<-1 || shadowpos.x>1 || shadowpos.y>1)
        return vec2(-100);
    return levelDistort(shadowpos,clamp(getMaxLevel(shadowpos*1.01),0,3));
}

vec3 distort(vec3 shadowpos, float noise){
    int level = int(getFloatMaxLevel(shadowpos.xy*1.01)-0.04*noise);
    return vec3(levelDistort(shadowpos.xy, min(level,3)),distortZ(shadowpos.z));
}
#else
vec2 distort(vec2 shadowpos){
//    float distortFactor = 1/(0.1+max(length(shadowpos)/1.2,0.05));
//    return vec2(shadowpos.xy*distortFactor);
    return shadowpos/(sqrt(abs(shadowpos))*0.97+0.03);
}
vec3 distort(vec3 shadowpos, float noise){
    return vec3(distort(shadowpos.xy),distortZ(shadowpos.z));
}
#endif

vec3 distort(vec3 shadowpos){
    return vec3(distort(shadowpos.xy),distortZ(shadowpos.z));
}