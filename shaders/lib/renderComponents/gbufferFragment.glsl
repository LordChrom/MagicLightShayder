#version 430 compatibility

#ifdef TEXTURED
in vec2 texcoord;
uniform sampler2D gtexture;
#endif

#ifdef LIT
in vec2 lmcoord;
uniform sampler2D lightmap;
#endif

#ifdef VERTEX_NORMALS
in vec3 normal;
#endif

#ifdef ALPHATEST
uniform float alphaTestRef = 0.1;
#endif

#ifdef ENTITY
uniform vec4 entityColor;
#endif

#ifdef HAND
#define HAND_MASK 1
#else
#define HAND_MASK 0
#endif

#ifdef BONUS_STUFF
void doBonusStuff();
#endif

in vec4 glcolor;

/* RENDERTARGETS: 0,4,5 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 normalOut;
layout(location = 2) out vec4 vanillaLighting;

void main() {
    #ifdef LIT
    vanillaLighting = texture(lightmap, lmcoord);
    #else
    vanillaLighting = vec4(1.0);
    #endif

    #ifdef TEXTURED
    color = glcolor * texture(gtexture, texcoord);
    #else
    color = glcolor * vanillaLighting;
    #endif

    #ifdef ENTITY
    color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);
    #endif

    #ifdef ALPHATEST
    if (color.a < alphaTestRef) {
        discard;
    }
    #endif

    #ifdef VERTEX_NORMALS
    normalOut = vec4((normal+1)*0.5,HAND_MASK);
    #endif

    #ifdef BONUS_STUFF
    doBonusStuff();
    #endif
}