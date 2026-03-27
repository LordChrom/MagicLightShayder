#version 430 compatibility

#ifdef BASIC
out flat vec4 glcolor;
#else
out vec4 glcolor;
#endif

#ifdef TEXTURED
out vec2 texcoord;
#endif

#ifdef VERTEX_NORMALS
out vec3 normal;
#endif

#ifdef LIT
out vec2 lmcoord;
const vec2 maxLm = vec2(15.0/16.0);
#endif

#if defined NORMALS_NOT_INCLUDED || defined HAND
uniform mat4 gbufferModelViewInverse;
#endif

#ifdef MAYBE_END_GATEWAY
uniform int blockEntityId;
out float material;
#endif

void main() {
    gl_Position = ftransform();

#ifdef TEXTURED
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#endif

#ifdef VERTEX_NORMALS

    #ifdef HAND
    normal = (gbufferModelViewInverse*vec4(gl_Normal,0)).xyz;
    #elif defined NORMALS_NOT_INCLUDED
    //TODO make these all subsurface
//    normal = (gbufferModelViewInverse*vec4(0,0,-1,0)).xyz;
    normal = (-gbufferModelViewInverse[2]).xyz;
    #else
    normal = gl_Normal;
    #endif
#endif

#ifdef LIT
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = min(lmcoord,maxLm);
#endif

#ifdef MAYBE_END_GATEWAY
    material=blockEntityId;
#endif

    glcolor = gl_Color;
}