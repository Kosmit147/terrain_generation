package terrain_generation

import "vendor/glue/vendor/imgui"

import "core:c"

imgui_drag_double :: proc(label: cstring,
			  v: ^c.double,
			  v_speed := f32(1),
			  v_min := f64(0),
			  v_max := f64(0),
			  format := cstring("%.3f"),
			  flags := imgui.SliderFlags{}) -> bool {
	v_min, v_max := v_min, v_max
	return imgui.DragScalar(label = label,
				data_type = .Double,
				p_data = v,
				v_speed = v_speed,
				p_min = &v_min,
				p_max = &v_max,
				format = format,
				flags = flags)
}

imgui_input_uint :: proc(label: cstring,
			 v: ^u32,
			 step: u32 = 1,
			 step_fast: u32 = 100,
			 flags: imgui.InputTextFlags = {}) -> bool {
	step, step_fast := step, step_fast
	return imgui.InputScalar(label = label,
				 data_type = .U32,
				 p_data = v,
				 p_step = &step,
				 p_step_fast = &step_fast,
				 format = nil,
				 flags = flags)
}

imgui_input_uint2 :: proc(label: cstring,
			  v: ^[2]u32,
			  step: u32 = 1,
			  step_fast: u32 = 100,
			  flags: imgui.InputTextFlags = {}) -> bool {
	step, step_fast := step, step_fast
	return imgui.InputScalarN(label = label,
				  data_type = .U32,
				  p_data = v,
				  components = 2,
				  p_step = &step,
				  p_step_fast = &step_fast,
				  format = nil,
				  flags = flags)
}
