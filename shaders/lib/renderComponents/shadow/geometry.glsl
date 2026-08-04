#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/renderComponents/shadow/shadowProgramFeatures.glsl"

layout(triangles) in;
#ifdef CAN_VOXELIZE
#include "/lib/voxel/voxelMapper.glsl"
uniform vec3 cameraPosition;

in flat int[] blockID;
in flat int[] blockEmission;
in vec3[] worldPosRel;
in vec3[] normal;
void voxelize(){
    vec3 minWorldPos = cameraPosition+min(min(worldPosRel[0],worldPosRel[1]),worldPosRel[2]);
    vec3 maxWorldPos = cameraPosition+max(max(worldPosRel[0],worldPosRel[1]),worldPosRel[2]);
    writeVoxelMap(minWorldPos, maxWorldPos, blockID[0], normal[0], blockEmission[0]);
}
#endif


#ifndef SHADOWMAP_SHADOWS
layout(triangle_strip, max_vertices = 0) out;
void main(){
    #ifdef CAN_VOXELIZE
    voxelize();
    #endif
}
#else


#ifdef TEXTURED
in vec2[] texcoordVert;
out vec2 texcoord;
#endif

#ifdef COLORED
in vec4[] glcolorVert;
out vec4 glcolor;
#elif defined CUTOUT
in float[] glcolorAlphaVert;
out float glcolorAlpha;
#endif


#ifndef CASCADED_SHADOWS
uniform bool hasCeiling;

//no cascades, just passthru
layout(triangle_strip, max_vertices = 3) out;

void main(){
    #ifdef CAN_VOXELIZE
    voxelize();
    #endif
    if(hasCeiling) return;
    for(int i=0;i<3;i++){
        gl_Position = gl_in[i].gl_Position;

        #ifdef TEXTURED
        texcoord = texcoordVert[i];
        #endif

        #ifdef COLORED
        glcolor = glcolorVert[i];
        #elif defined CUTOUT
        glcolorAlpha = glcolorAlphaVert[i];
        #endif
        EmitVertex();
    }
    EndPrimitive();
}

#else
uniform bool hasCeiling;
//yes cascasdes
layout(triangle_strip, max_vertices = 12) out;
#include "/lib/shadowmap/distortion.glsl"

void main(){
    #ifdef CAN_VOXELIZE
    voxelize();
    #endif
    if(hasCeiling) return;
    float fudge = 0.9;
    int maxLevel=max(getMaxLevel(gl_in[0].gl_Position.xy*fudge),max(getMaxLevel(gl_in[1].gl_Position.xy*fudge),getMaxLevel(gl_in[2].gl_Position.xy*fudge)));
    maxLevel=min(maxLevel,3);
    for(int level=0;level<=maxLevel;level++){
        vec2[3] positions;
        bool allOob = true;
        for (int i=0;i<3;i++){
            bool oob;
            positions[i]=levelDistortAndReport(gl_in[i].gl_Position.xy,level,oob);
            allOob = allOob&& oob;
        }
        if(allOob)
            return;

        for (int i=0;i<3;i++){
            gl_Position.zw = gl_in[i].gl_Position.zw;
            gl_Position.xy=positions[i].xy;
            #ifdef TEXTURED
            texcoord = texcoordVert[i];
            #endif

            #ifdef COLORED
            glcolor = glcolorVert[i];
            #elif defined CUTOUT
            glcolorAlpha = glcolorAlphaVert[i];
            #endif
            EmitVertex();
        }
        EndPrimitive();
    }
}
#endif
#endif