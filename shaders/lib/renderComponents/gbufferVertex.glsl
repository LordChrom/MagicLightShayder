#version 430 compatibility

#if MATERIALS_TYPE < 0
    #undef WRITE_MATERIALS
#endif

#if (defined WRITE_MATERIALS) && (MATERIALS_TYPE == 0)
    #define NEEDS_MATERIAL_ID
#endif

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

#ifdef NEEDS_MATERIAL_ID
    #ifdef BLOCK_ENTITY
        uniform int blockEntityId;
    #else
        in vec2 mc_Entity;
    #endif
out int materialID;
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

#ifdef NEEDS_MATERIAL_ID
    #ifdef BLOCK_ENTITY
        materialID=blockEntityId;
    #else
    //TODO handle old versions, optifine jank
        float awa = mc_Entity.x*1.0;
        materialID = int(round(awa));
    #endif
#endif

    glcolor = gl_Color;
}