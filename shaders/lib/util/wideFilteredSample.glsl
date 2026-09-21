vec4 wideSample(sampler2D tex, vec2 texcoord){
    vec4 ret =texture(tex,texcoord,0)*0.25;

    vec2 pixelSize = 1.0/textureSize(tex,0);

    ret+=texture(tex,texcoord+pixelSize*vec2(0.5,1.5));
    ret+=texture(tex,texcoord+pixelSize*vec2(-0.5,-1.5));
    ret+=texture(tex,texcoord+pixelSize*vec2(1.5,-0.5));
    ret+=texture(tex,texcoord+pixelSize*vec2(-1.5,0.5));

    return ret/4.25;
}

vec4 fourNeighborsSample(sampler2D tex, vec2 texcoord){
    vec2 pixelSize = 1.0/textureSize(tex,0);
    return texture(tex,round(texcoord/pixelSize)*pixelSize,0);
}