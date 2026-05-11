#include "/lib/settings.glsl"

int dFromLevel(int level){
    return int(round(exp2(level)));
}

float weightAtOffset(float rad,int x, int y, int d){
    if(!(bool(x)||bool(y)))
        return 1;

    float len = length(vec2(x,y));
    if(d>1 && (max(abs(x),abs(y))<<1)<=DOF_SIZE && rad>0.5*len){ //keeps things approximately uniform
        return 0;
    }
    float steepness=0.3/d+0.2;
    return clamp(0.5+(steepness)*(rad-len), 0, 1);
}

float totalWeightAtOffset(float rad, int d){
    float total = 0;
    for(int x=d;x<=d*DOF_SIZE;x+=d){
        for(int y=0;y<=x;y+=d){
            float weight = weightAtOffset(rad,x,y,d);
            total+=(y==0 || x==y)?weight:(weight+weight);
        }
    }
    return total*4+1.0;
}