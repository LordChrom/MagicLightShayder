#version 330 compatibility

uniform sampler2D lightmap;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;

/* RENDERTARGETS: 0,4,5 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 normalOut;
layout(location = 2) out vec4 vanillaLighting;

void main() {
    color = glcolor * texture(lightmap, lmcoord);
    if (color.a < alphaTestRef) {
        discard;
    }
    vanillaLighting = texture(lightmap, lmcoord);
    normalOut = vec4((normal+1)*0.5,0);
}