#ifndef LIGHT_FALLOFF_GLSL
#define LIGHT_FALLOFF_GLSL
float lightFalloff(vec3 displacement){
    #ifdef MC_SHAPED_LIGHT_FALLOFF
    displacement=max(abs(displacement)-0.5,0);
    vec3 a = unpackLightColor(packedLightSrc);
    float base = (a.x+a.y+a.b)/3.0;
    float lightStrength = 2*max(0,base-(displacement.x+displacement.y+displacement.z)/15.0)/base;
    #else
    const float b = 1/float(MAX_LIGHT_STRENGTH*MAX_LIGHT_STRENGTH);
    float lengthSquared = dot(displacement,displacement);
    float lightStrength = BLOCK_LIGHT_STRENGTH*inversesqrt(lengthSquared*lengthSquared*(1-MIN_COLUMNATION)+b);
    #endif
    return lightStrength;
}
#endif