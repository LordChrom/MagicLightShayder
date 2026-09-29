vec3 blend(vec4 behind, vec4 infront){
    float a = infront.a;
    return infront.rgb*a+behind.rgb*(1-a);
}

vec3 mixInTranslucent(vec3 solidColor, vec4 transColor){
    solidColor = blend(vec4(solidColor,1),transColor);
    return solidColor;
}