vec3 blend(vec4 behind, vec4 infront){
    float a = infront.a;
    return infront.rgb*a+behind.rgb*(1-a);
}