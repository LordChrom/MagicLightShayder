vec2 distort(vec2 shadowpos){
    float distortFactor = 1/(0.1+sqrt(dot(shadowpos,shadowpos)));
//    float distortFactor = 1/(max(abs(shadowpos.x),abs(shadowpos.y)));
    return shadowpos*distortFactor;
}