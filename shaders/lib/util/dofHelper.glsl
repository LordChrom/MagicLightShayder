#include "/lib/settings.glsl"

const int DOF_SAMPLE_RAD = DOF_RAD>>(DOF_PASSES-1);

//total cost = (DOF_RAD>>DOF_PASSES)**2 * DOF_PASSES
// = O(n^2) rad, O(n/2^n) quality

float weightAtOffset(float rad,float len, int d){
    int level = int(log2(d));
    if(len==0)
        return 1;

    float ret = clamp(d*(rad-len)/(rad+3), 0, 1);
    if(d>1){ //keeps things approximately uniform
        float lenDif = len+len-DOF_SAMPLE_RAD;
        ret*=clamp(0.01*(0.5*lenDif*lenDif+(rad-len)*(rad-len)),1e-3,1e2);
    }
    return ret;
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