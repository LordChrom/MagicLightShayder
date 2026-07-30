#version 430 compatibility
#include "/lib/settings.glsl"
layout(triangles) in;

#ifndef SHADOWMAP_SHADOWS
//no shadows
layout(triangle_strip, max_vertices = 0) out;
void main(){}
#else



in vec2[] texcoordVert;
in vec4[] glcolorVert;
out vec2 texcoord;
out vec4 glcolor;

#ifndef CASCADED_SHADOWS
//no cascades, just passthru
layout(triangle_strip, max_vertices = 3) out;

void main(){
    for(int i=0;i<3;i++){
        gl_Position = gl_in[i].gl_Position;
        texcoord = texcoordVert[i];
        glcolor = glcolorVert[i];
        EmitVertex();
    }
    EndPrimitive();
}

#else
//yes cascasdes
layout(triangle_strip, max_vertices = 12) out;
#include "/lib/shadowmap/distortion.glsl"

void main(){
    vec2 avgPos = (gl_in[0].gl_Position.xy+gl_in[1].gl_Position.xy+gl_in[2].gl_Position.xy)/3.0;
    int maxLevel = getMaxLevel(avgPos*0.9);
    maxLevel=min(maxLevel,3);
    for(int level=0;level<=maxLevel;level++){
        vec2[3] positions;
        bool allOob = true;
        for (int i=0;i<3;i++){
            bool oob;
            positions[i]=levelDistortAndReport(gl_in[i].gl_Position.xy,level,oob);
//            positions[i]=levelDistort(gl_in[i].gl_Position.xy,level);
            allOob = allOob&& oob;
        }
        if(allOob)
            return;
        for (int i=0;i<3;i++){
            gl_Position.xy = positions[i];
            gl_Position.zw=gl_in[i].gl_Position.zw;
            texcoord = texcoordVert[i];
            glcolor = glcolorVert[i];
            EmitVertex();
        }
        EndPrimitive();
    }
}
#endif
#endif