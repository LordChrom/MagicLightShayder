#include "/lib/settings.glsl"

float weightAtOffset(float rad,float len, int d){
    if(len==0)
        return 1;
    if(d>1 && (len+len)<=DOF_SAMPLE_RAD && rad+rad>=len){ //keeps things approximately uniform
        return 0;
    }
    float steepness = d;
    return clamp(steepness*(rad-len)/(rad+3), 0, 1);
}

float totalWeightAtOffset(float rad, int d){
    float total = 0;


    for(int x=1;x<=DOF_SAMPLE_RAD;x++){
        for(int y=0;y<=x;y++){
            float len = length(ivec2(x,y));
            if(len>DOF_SAMPLE_RAD) continue;
            len*=d;
            float weight = weightAtOffset(rad,len,d);
            total+=(y==0 || x==y)?weight:(weight+weight);
        }
    }
    return total*4+weightAtOffset(rad,0,d);
}