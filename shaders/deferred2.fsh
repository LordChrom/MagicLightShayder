#version 430 compatibility

in vec2 texcoord;

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 voxelLighting;

uniform sampler2D colortex6;

void main(){
    voxelLighting=texelFetch(colortex6,ivec2(gl_FragCoord),0);
    vec2 pixelSize = 1.0/textureSize(colortex6,0);

    float ssao=voxelLighting.a*0.25;
    ssao+=texture(colortex6,texcoord+pixelSize*vec2(0.5,1.5)).a;
    ssao+=texture(colortex6,texcoord+pixelSize*vec2(-0.5,-1.5)).a;
    ssao+=texture(colortex6,texcoord+pixelSize*vec2(1.5,-0.5)).a;
    ssao+=texture(colortex6,texcoord+pixelSize*vec2(-1.5,0.5)).a;


    ssao/=4.25;
    voxelLighting.rgb*=ssao/voxelLighting.a;
}