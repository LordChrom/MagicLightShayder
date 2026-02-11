#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

const vec2 maxLm = vec2(15.0/16.0,15.0/16.0);

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	color *= texture(lightmap, min(lmcoord,maxLm));
	if (color.a < alphaTestRef) {
		discard;
	}
}