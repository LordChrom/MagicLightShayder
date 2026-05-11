#include "/lib/settings.glsl"

int dFromLevel(int level){
    return int(round(exp2(level)));
}

float weightAtOffset(float rad,int x, int y, int d){
    if(x==0 && y==0)
        return 1;

    float steepness=0.6/d;
    return clamp(0.5+(steepness)*(rad-length(vec2(x*x,y*y))), 0, 1);
}

int distort(int x, int d){
    return (d*x);//<<clamp(int((abs(x)>>2)),0,2);
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