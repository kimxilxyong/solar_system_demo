// Renders an approximate silouhette of clouds coverage so it can be used
// to project shadows using classic shadow mapping.
// Such shadows may not be realistic, it's a cheap compromise.
// Light3D `angular_distance` may help with smoothing.

shader_type spatial;

uniform samplerCube u_cloud_coverage_cubemap;
uniform mat2 u_cloud_coverage_rotation;
uniform float u_bias = 0.0;

varying vec3 v_pos_model;

void vertex() {
	v_pos_model = VERTEX;
}

void fragment() {
	vec3 pos_model = v_pos_model;
	vec2 cov_pos_2d = u_cloud_coverage_rotation * vec2(pos_model.x, pos_model.z);
	vec3 cov_pos = vec3(cov_pos_2d.x, pos_model.y, cov_pos_2d.y);
	float cov = texture(u_cloud_coverage_cubemap, cov_pos).r;
	if (cov < 0.5 - u_bias) {
		discard;
	}
}
