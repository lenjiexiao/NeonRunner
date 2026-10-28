shader_type canvas_item;
// 合成波背景：渐变天空 + 星空 + 复古落日 + 透视网格地面

uniform float horizon = 0.802; // 地平线（屏幕高度比例），与游戏地面 y=520/648 对齐
uniform float scroll = 0.0;    // 网格滚动量（随跑动距离增加）
uniform float flash = 0.0;    // 死亡白闪
uniform vec3 top_color : source_color = vec3(0.04, 0.01, 0.10);
uniform vec3 mid_color : source_color = vec3(0.15, 0.03, 0.30);
uniform vec3 grid_color : source_color = vec3(0.00, 0.85, 1.00);
uniform vec3 sun_color : source_color = vec3(1.00, 0.22, 0.55);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color, mid_color, smoothstep(0.0, horizon, uv.y));

	// 星空（只在地平线上方，带闪烁）
	if (uv.y < horizon - 0.02) {
		vec2 sp = floor(uv * vec2(90.0, 55.0));
		float h = hash(sp);
		float tw = 0.6 + 0.4 * sin(TIME * (1.5 + h * 3.0) + h * 20.0);
		if (h > 0.985) {
			col += vec3(0.9, 0.95, 1.0) * tw;
		}
	}

	// 复古落日（横条纹切割 + 光晕）
	vec2 sun_uv = vec2(0.5, horizon - 0.22);
	float dist = length((uv - sun_uv) * vec2(1.0, 1.35));
	float disk = smoothstep(0.155, 0.150, dist);
	float stripes = step(0.35, fract(uv.y * 60.0 + 0.1));
	float sun = disk * stripes;
	col = mix(col, sun_color, sun);
	col += sun_color * 0.35 * smoothstep(0.30, 0.15, dist) * (1.0 - sun);

	// 透视网格地面
	if (uv.y > horizon) {
		float gy = clamp((uv.y - horizon) / (1.0 - horizon), 0.0, 1.0);
		float g = max(gy, 0.02);
		float k = 1.0 / g; // 1（近）→ 50（远）

		// 横线：越远越密，随 scroll 向观察者移动
		float hy = abs(fract(k * 0.5 - scroll + 0.5) - 0.5);
		float hline = smoothstep(0.06, 0.0, hy * (0.3 + gy * 0.7));

		// 竖线：向中央消失点汇聚
		float xv = (uv.x - 0.5) * (4.0 / g);
		float dv = abs(fract(xv + 0.5) - 0.5);
		float vline = smoothstep(0.05, 0.0, dv);

		float fade = smoothstep(0.0, 0.18, gy); // 靠近地平线渐隐
		float lines = max(hline, vline) * fade;
		col += grid_color * lines * (0.30 + 0.70 * gy);
		col += grid_color * lines * lines * 0.4; // 高光增强
	}

	// 地平线发光带
	col += grid_color * smoothstep(0.012, 0.0, abs(uv.y - horizon)) * 0.8;

	// 死亡白闪
	col = mix(col, vec3(1.0), flash * 0.7);

	COLOR = vec4(col, 1.0);
}
