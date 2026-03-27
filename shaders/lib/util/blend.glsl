vec4 blend(vec4 behind, vec4 infront){
    float a = infront.a;
    return vec4(infront.rgb*a+behind.rgb*(1-a),behind.a);
//    return vec4(infront.rgb*a+behind.rgb*(1-a),a+a*behind.a);
}