package terrain_generation

import "base:runtime"

import "vendor/glue"
import gl "vendor:OpenGL"

import "core:math/noise"
import "core:math/linalg"
import "core:slice"
import "core:log"

GENERATOR_SEED :: 0

Terrain_Mesh_Vertex :: struct {
	position: Vec3,
}

@(rodata)
terrain_mesh_vertex_format := [?]glue.Vertex_Attribute {
	.Float_3,
}

Terrain_Mesh_Index :: u32

// Composed of triangle strips.
Terrain_Mesh :: struct {
	using mesh: glue.Mesh,
	strip_count: u32,
	vertices_per_strip: u32,
}

create_terrain_mesh :: proc(width, height: u32, params: Terrain_Generation_Params) -> (mesh: Terrain_Mesh) {
	mesh_data := generate_terrain_mesh(width, height, params, context.temp_allocator)
	defer free_terrain_mesh_data(mesh_data)
	glue.create_mesh(mesh = &mesh,
			 vertices = slice.to_bytes(mesh_data.vertices[:]),
			 vertex_stride = size_of(Terrain_Mesh_Vertex),
			 vertex_format = terrain_mesh_vertex_format[:],
			 indices = slice.to_bytes(mesh_data.indices[:]),
			 index_type = glue.gl_index(Terrain_Mesh_Index))
	mesh.strip_count = mesh_data.strip_count
	mesh.vertices_per_strip = mesh_data.vertices_per_strip
	return
}

destroy_terrain_mesh :: proc(mesh: ^Terrain_Mesh) {
	glue.destroy_mesh(mesh)
}

draw_terrain_mesh :: proc(mesh: Terrain_Mesh) {
	glue.bind_mesh(mesh)
	for i in 0..<mesh.strip_count {
		index_offset := mesh.index_data_offset + size_of(Terrain_Mesh_Index) * mesh.vertices_per_strip * i
		gl.DrawElements(mode = gl.TRIANGLE_STRIP,
				count = i32(mesh.vertices_per_strip),
				type = mesh.index_type,
				indices = cast(rawptr)uintptr(index_offset))
	}
}

Terrain_Generation_Params :: struct {
	smoothness: f64,
}

DEFAULT_TERRAIN_GENERATION_PARAMS :: Terrain_Generation_Params {
	smoothness = 0.15,
}

Terrain_Mesh_Data :: struct {
	vertices: [dynamic]Terrain_Mesh_Vertex,
	indices: [dynamic]Terrain_Mesh_Index,
	strip_count: u32,
	vertices_per_strip: u32,
}

generate_terrain_mesh :: proc(width, height: u32,
			      params: Terrain_Generation_Params,
			      allocator := context.allocator) -> Terrain_Mesh_Data {
	vertices := make([dynamic]Terrain_Mesh_Vertex, allocator)
	indices := make([dynamic]Terrain_Mesh_Index, allocator)

	for y in 0..<height {
		for x in 0..<width {
			coord := linalg.array_cast([2]u32{ x, y }, f64)
			height := noise.noise_2d(GENERATOR_SEED, coord * params.smoothness)
			append(&vertices, Terrain_Mesh_Vertex{ position = { f32(coord.x), height, f32(coord.y) } })
		}
	}

	for y in 1..<height {
		for x in 0..<width {
			append(&indices, (y - 1) * width + x)
			append(&indices, y * width + x)
		}
	}

	return Terrain_Mesh_Data {
		vertices = vertices,
		indices = indices,
		strip_count = height - 1 if height > 0 else 0,
		vertices_per_strip = 2 * width,
	}
}

free_terrain_mesh_data :: proc(mesh: Terrain_Mesh_Data) {
	delete(mesh.vertices)
	delete(mesh.indices)
}
