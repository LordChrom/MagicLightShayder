#version 430 compatibility
#include "/lib/settings.glsl"

#if MATERIALS_TYPE < 0
    #undef WRITE_MATERIALS
#endif

#if (defined WRITE_MATERIALS) && (MATERIALS_TYPE == 0)
    #define HARDCODED_MATERIAL
    flat out uvec4 hardcodedMaterialInfo;
    #ifdef SELECTIVE_HARDCODED_EMISSIVE
        #define NEEDS_MATERIAL_ID
    #endif
#endif

#ifdef BASIC
out flat vec4 glcolor;
#else
out vec4 glcolor;
#endif

#ifdef TEXTURED
out vec2 texcoord;
    #if MATERIALS_TYPE == 1
    in vec4 at_tangent;
    flat out mat3 normalRotator;
    #endif
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


#if ( VOXELIZATION_MODE ==1 ) && (defined IS_TERRAIN )
    #include "/lib/voxel/voxelMapper.glsl"
    uniform vec3 cameraPosition;
    in vec4 at_midBlock;
    #define UPDATE_VOXEL_MAP
    #define NEEDS_MC_ENTITY
#endif

#if (defined NEEDS_MATERIAL_ID) || (defined HARDCODED_MATERIAL)
    #ifdef BLOCK_ENTITY
        uniform int blockEntityId;
    #else
        #define NEEDS_MC_ENTITY
    #endif
#endif

#ifdef NEEDS_MATERIAL_ID
flat out int materialID;
#endif

#ifdef NEEDS_MC_ENTITY
in vec2 mc_Entity;
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
//    normal = (gbufferModelViewInverse*vec4(0,0,1,0)).xyz;
    normal = (gbufferModelViewInverse[2]).xyz;
    #else
    normal = gl_Normal;
    #endif

    #if MATERIALS_TYPE == 1 && defined TEXTURED
    normalRotator = mat3(at_tangent.xyz,normalize(cross(at_tangent.xyz,normal)*at_tangent.w),normal);
    #endif
#endif

#ifdef LIT
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = min(lmcoord,maxLm);
#endif

#if (defined NEEDS_MATERIAL_ID) || (defined HARDCODED_MATERIAL)
    #ifndef NEEDS_MATERIAL_ID
        int materialID;
    #endif

    #ifdef BLOCK_ENTITY
        materialID = blockEntityId;
        if(materialID==65535)
            materialID=-1;
    #else
    //TODO handle old versions, optifine jank
        materialID = int(round(mc_Entity.x));
    #endif
#endif

#ifdef HARDCODED_MATERIAL

    int meta = ((materialID/1000)%10);

    float subsurface = 0;
    uint emissive = 0;
    float porosity = 0;

    if(materialID>=0){
        subsurface = ((materialID%10000)==15)?1.0:0;
        emissive = bool(meta&4)?254:0;
    }

    hardcodedMaterialInfo=clamp(uvec4(
        0,
        0,
        (porosity>0.01)?porosity*64:64+subsurface*190.0,
        emissive
    ),0u,255u);
#endif

#ifdef UPDATE_VOXEL_MAP
    int emission = int(at_midBlock.w);

    vec3 worldPos = gl_Vertex.xyz-gl_ProjectionMatrix[3].xyz+cameraPosition;
    vec3 toMidblock = at_midBlock.xyz/64.0;
    int blockId = int(mc_Entity.x);
    writeVoxelMap(worldPos,blockId,toMidblock,gl_Normal,emission);
#endif

    glcolor = gl_Color;
}