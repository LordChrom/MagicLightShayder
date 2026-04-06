vec3 getMaterialColor(int materialId){
    vec3 ret;
    ret.r=(materialId/100)%10;
    ret.g=(materialId/10)%10;
    ret.b=(materialId)%10;
    return ret/9;
}

uvec4 getHardcodedMaterial(int materialID){
    int meta = ((materialID/1000)%10);

    float subsurface = 0;
    uint emissive = 0;
    float porosity = 0;

    if(materialID>=0){
        subsurface = ((materialID%10000)==15)?1.0:0;
        emissive = bool(meta&4)?254:0;
    }

    return clamp(uvec4(
        0,
        0,
        (porosity>0.01)?porosity*64:64+subsurface*190.0,
        emissive
    ),0u,255u);
}