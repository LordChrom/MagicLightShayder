#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/renderComponents/shadow/shadowProgramFeatures.glsl"

layout(triangles) in;

#ifndef SHADOWMAP_SHADOWS
//no shadows
layout(triangle_strip, max_vertices = 0) out;
void main(){}
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
    if(hasCeiling) return;
    vec2 avgPos = (gl_in[0].gl_Position.xy+gl_in[1].gl_Position.xy+gl_in[2].gl_Position.xy)/3.0;
    int maxLevel = getMaxLevel(avgPos*0.8);
    maxLevel=min(maxLevel,3);
    for(int level=0;level<=maxLevel;level++){
        for (int i=0;i<3;i++){
            gl_Position = gl_in[i].gl_Position;
            gl_Position.xy=levelDistort(gl_Position.xy,level);
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