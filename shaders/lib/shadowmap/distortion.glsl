vec2 distort(vec2 shadowpos){
    float distortFactor = 1/(0.1+max(length(shadowpos),0.05));
    return vec2(shadowpos.xy*distortFactor);
}

vec3 distort(vec3 shadowpos){
    return vec3(distort(shadowpos.xy),shadowpos.z*0.5);
}