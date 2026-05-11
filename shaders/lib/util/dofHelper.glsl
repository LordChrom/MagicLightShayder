#include "/lib/settings.glsl"

int dFromLevel(int level){
    return int(round(exp2(level)));
}

float weightAtOffset(float rad,int x, int y, int d){
    float len = length(vec2(x,y));
    float ret;
    if(x==0 && y==0){
        ret = 1;

    }else {
        float steepness=0.3/d+0.2;
        ret = clamp(0.5+(steepness)*(rad-len), 0, 1);
    }

    if(d>1 && rad>d*DOF_SIZE){ //keeps things approximately uniform ish kinda
        ret*=clamp(rad/(len*len),0.5,1.0);
    }

    return ret;
}

int distort(int x, int d){
    int ret = x*d;
    #ifdef DOF_DISTORTION
    ret<<=clamp(int((abs(x)>>2)),0,1);
    #endif
    return ret;
}

float totalWeightAtOffset(float rad, int d){
    float total = 0;
    for(int i=0;i<=DOF_SIZE;i++){
        float localWeight = bool(i)?2.0:1.0;
        int x = distort(i,d);
        for(int j=0;j<=DOF_SIZE;j++){
            int y = distort(j,d);

            float weight = weightAtOffset(rad,x,y,d);
            total+=weight*(bool(j)?(localWeight+localWeight):localWeight);
        }
    }
    return total;
}