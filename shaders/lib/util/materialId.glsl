vec3 getMaterialColor(int materialId){
    vec3 ret;
    ret.r=(materialId/100)%10;
    ret.g=(materialId/10)%10;
    ret.b=(materialId)%10;
    return ret/9;
}