#include "/lib/settings.glsl"

int dFromLevel(int level){
    return int(round(exp2(level)));
}

float weightAtOffset(float rad,int x, int y, int d){
    if(x==0 && y==0)
        return 1;

    float steepness=0.6/d;
    return clamp(0.5+(steepness)*(rad-length(vec2(x,y))), 0, 1);
}

float totalWeightAtOffset(float rad, int d){
    float total = 0;
    for(int x=0;x<=DOF_SIZE;x++){
        float localWeight = bool(x)?2.0:1.0;
        for(int y=0;y<=DOF_SIZE;y++){
            total+=weightAtOffset(rad,x*d,y*d,d)*(bool(y)?(localWeight+localWeight):localWeight);
        }
    }
    return total;
}