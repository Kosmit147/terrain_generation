package terrain_generation

import "vendor/glue"
import "vendor/glue/vendor/imgui"
import gl "vendor:OpenGL"

import "core:log"
import "core:math"
import "core:math/linalg"
import "core:fmt"

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Mat4 :: matrix[4, 4]f32

@(rodata) vertex_source := #load("terrain.vert", string)
@(rodata) fragment_source := #load("terrain.frag", string)

WINDOW_TITLE  :: "Terrain Generation"
WINDOW_WIDTH  :: 1920
WINDOW_HEIGHT :: 1080

BASE_MOVEMENT_SPEED :: 100
SHIFT_SPEEDUP :: 5
MOUSE_SENSITIVITY :: 1
DEFAULT_TERRAIN_SCALE :: 5
DEFAULT_TERRAIN_MESH_WIDTH :: 800
DEFAULT_TERRAIN_MESH_HEIGHT :: 800

main :: proc() {
	context.logger = log.create_console_logger(.Debug when ODIN_DEBUG else .Info)
	defer log.destroy_console_logger(context.logger)

	if !glue.init(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE, maximized = true, vsync = false, fps_limit = 120) {
		log.panic("Failed to init glue.")
	}
	defer glue.deinit()

	glue.set_cursor_enabled(false)
	glue.set_raw_mouse_motion_enabled(true)

	gl.Enable(gl.DEPTH_TEST)
	gl.Enable(gl.CULL_FACE)
	gl.CullFace(gl.BACK)
	gl.FrontFace(gl.CCW)
	gl.Disable(gl.BLEND)

	terrain_shader, terrain_shader_ok := glue.create_shader(vertex_source, fragment_source)
	if !terrain_shader_ok do log.panic("Failed to compile the terrain shader.")
	defer glue.destroy_shader(terrain_shader)

	camera := glue.Camera {
		position = { 0, 50, 0 },
		yaw = math.to_radians(f32(45.0)),
	}

	model_uniform := glue.get_uniform(terrain_shader, "model", Mat4)
	view_uniform := glue.get_uniform(terrain_shader, "view", Mat4)
	projection_uniform := glue.get_uniform(terrain_shader, "projection", Mat4)

	glue.use_shader(terrain_shader)
	gl.ClearColor(0, 0, 0, 1)

	terrain_mesh_size := [2]u32{ DEFAULT_TERRAIN_MESH_WIDTH, DEFAULT_TERRAIN_MESH_HEIGHT }
	terrain_scale: f32 = DEFAULT_TERRAIN_SCALE
	terrain_params := DEFAULT_TERRAIN_GENERATION_PARAMS
	terrain_mesh := create_terrain_mesh(terrain_mesh_size.x, terrain_mesh_size.y, terrain_params)
	defer destroy_terrain_mesh(&terrain_mesh)

	wireframe_enabled := false

	prev_time := glue.time()

	for !glue.window_should_close() {
		glue.begin_frame()

		time := glue.time()
		dt := f32(time - prev_time)
		prev_time = time

		for event in glue.pop_event() {
			#partial switch event in event {
			case glue.Key_Pressed_Event:
				if event.key == .Escape {
					glue.close_window()
				} else if event.key == .Left_Control {
					glue.set_cursor_enabled(!glue.cursor_enabled())
				} else if event.key == .F_1 {
					wireframe_enabled = !wireframe_enabled
					set_wireframe_enabled(wireframe_enabled)
				}
			}
		}

		imgui.Begin("Info")
		imgui.TextUnformatted(fmt.ctprintf("Camera position: %v", camera.position))
		imgui_io := imgui.GetIO()
		imgui.TextUnformatted(fmt.ctprintf("FPS: %v", imgui_io.Framerate))
		imgui.End()

		imgui.Begin("Settings")
		if imgui.BeginTabBar("Settings Tab Bar") {
			if imgui.BeginTabItem("Terrain") {
				imgui_input_uint2("Mesh Resolution", &terrain_mesh_size)
				imgui.DragFloat("Mesh Scale", &terrain_scale, v_speed = 0.01, v_min = 0, v_max = 1000)
				imgui_drag_double("Smoothness",
						  &terrain_params.smoothness,
						  v_speed = 0.001,
						  v_min = 0.001,
						  v_max = 1)
				if imgui.Button("Regenerate mesh") {
					destroy_terrain_mesh(&terrain_mesh)
					terrain_mesh = create_terrain_mesh(terrain_mesh_size.x,
									   terrain_mesh_size.y,
									   terrain_params)
				}
				imgui.EndTabItem()
			}
			if imgui.BeginTabItem("Renderer") {
				if imgui.Checkbox("Wireframe", &wireframe_enabled) {
					set_wireframe_enabled(wireframe_enabled)
				}
				imgui.EndTabItem()
			}
			imgui.EndTabBar()
		}
		imgui.End()

		if !glue.cursor_enabled() {
			cursor_position_delta := linalg.array_cast(glue.cursor_position_delta(), f32)
			camera.yaw += cursor_position_delta.x * MOUSE_SENSITIVITY * 0.001
			camera.pitch += -cursor_position_delta.y * MOUSE_SENSITIVITY * 0.001
			camera.pitch = clamp(camera.pitch, math.to_radians(f32(-89)), math.to_radians(f32(89)))
		}

		camera_vectors := glue.camera_vectors(camera)

		movement_speed: f32 = BASE_MOVEMENT_SPEED
		if glue.key_pressed(.Left_Shift) do movement_speed *= SHIFT_SPEEDUP
		if glue.key_pressed(.W) do camera.position += camera_vectors.forward * movement_speed * dt
		if glue.key_pressed(.S) do camera.position -= camera_vectors.forward * movement_speed * dt
		if glue.key_pressed(.A) do camera.position -= camera_vectors.right   * movement_speed * dt
		if glue.key_pressed(.D) do camera.position += camera_vectors.right   * movement_speed * dt

		model: Mat4 = linalg.matrix4_scale(Vec3{ terrain_scale, terrain_scale, terrain_scale })
		view := linalg.matrix4_look_at(eye = camera.position,
					       centre = camera.position + camera_vectors.forward,
					       up = camera_vectors.up)
		projection := linalg.matrix4_perspective(fovy = math.to_radians(f32(45)),
							 aspect = glue.window_aspect_ratio(),
							 near = 0.1,
							 far = 10000) // 10000 might be too high.

		glue.set_uniform(terrain_shader, model_uniform, model)
		glue.set_uniform(terrain_shader, view_uniform, view)
		glue.set_uniform(terrain_shader, projection_uniform, projection)

		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
		draw_terrain_mesh(terrain_mesh)

		glue.end_frame()
		free_all(context.temp_allocator)
	}
}

set_wireframe_enabled :: proc(enabled: bool) {
	gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE if enabled else gl.FILL)
}
