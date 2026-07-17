#version 430

#include "lib/settings.glsl"

#define STAGES 3
#define source colortex7
#define dest colorimg13
layout (rgba16f) uniform writeonly restrict image2D dest;

#include "lib/renderComponents/downsamplePass.glsl"
