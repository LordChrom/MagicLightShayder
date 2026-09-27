vec4 wideSample(sampler2D tex, vec2 texcoord){
    vec2 ts = textureSize(tex,0);
//    texcoord = (floor(texcoord*ts)+0.5)/ts;
    vec4 ret =texture(tex,texcoord)*0.25;

    vec2 pixelSize = 1.0/ts;

    ret+=texture(tex,texcoord+pixelSize*vec2(0.5,1.5));
    ret+=texture(tex,texcoord+pixelSize*vec2(-0.5,-1.5));
    ret+=texture(tex,texcoord+pixelSize*vec2(1.5,-0.5));
    ret+=texture(tex,texcoord+pixelSize*vec2(-1.5,0.5));

    return ret/4.25;
}

vec4 fourNeighborsSample(sampler2D tex, vec2 texcoord){
    vec2 ts = textureSize(tex,0);
    return texture(tex,round(texcoord*ts)/ts);
}