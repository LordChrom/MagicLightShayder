#version 430 compatibility

out vec4 glcolor;

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

#ifdef HAND
uniform mat4 gbufferModelViewInverse;
#endif

void main() {
    gl_Position = ftransform();

#ifdef TEXTURED
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#endif

#ifdef VERTEX_NORMALS
    normal = gl_Normal;

    #ifdef HAND
    normal = (gbufferModelViewInverse*vec4(normal,0)).xyz;
    #endif
#endif

#ifdef LIT
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = min(lmcoord,maxLm);
#endif

    glcolor = gl_Color;
}