extends Node3D
## Performance benchmark runner for SO FLUFFY.
## Usage: godot --path . --disable-vsync --resolution 1280x720 res://bench/bench.tscn -- scenario=<name> out=<abs path>
## See bench/run.sh and bench/compare.py.

const FUR: GDScript = preload("res://addons/so_fluffy/so_fluffy.gd")
const WARMUP: int = 90
const FRAMES: int = 600

var scenario: String = "fill"
var out_path: String = ""
var shot_path: String = "" # optional: save a screenshot mid-run, for eyeballing that a change still renders correctly
var frame: int = 0
var tick: int = 0
var last_usec: int = 0
var load_ms: float = 0.0
var cam: Camera3D
var movers: Array[Node3D] = []
var dolly: bool = false
var fast_motion: bool = false
var samples: Dictionary = {
	"frame_ms": [], "gpu_ms": [], "render_cpu_ms": [],
	"script_process_ms": [], "script_physics_ms": [], "draw_calls": [],
}
# Script time is measured between this node (runs first) and a probe node (runs last).
var process_start: int = 0
var physics_start: int = 0
var process_usec: int = 0
var physics_usec: int = 0


class Probe extends Node:
	var bench: Node
	func _process(_d: float) -> void:
		bench.process_usec = Time.get_ticks_usec() - bench.process_start
	func _physics_process(_d: float) -> void:
		bench.physics_usec += Time.get_ticks_usec() - bench.physics_start


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		if kv.size() == 2:
			if kv[0] == "scenario": scenario = kv[1]
			if kv[0] == "out": out_path = kv[1]
			if kv[0] == "shot": shot_path = kv[1]

	process_priority = -1000
	process_physics_priority = -1000
	var probe: Probe = Probe.new()
	probe.bench = self
	probe.process_priority = 1000
	probe.process_physics_priority = 1000
	add_child(probe)

	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

	cam = Camera3D.new()
	add_child(cam)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	add_child(light)

	var t0: int = Time.get_ticks_usec()
	match scenario:
		"fill":
			# one screen-filling object: fragment-bound
			add_furry(Vector3.ZERO, 1.0, 64, 32, 64, false, true)
			cam.position = Vector3(0, 0, 2.0)
		"physics_close":
			# one large moving object seen close up: for eyeballing physics via shot=
			add_furry(Vector3.ZERO, 1.0, 64, 32, 64, false, true)
			var soft: Node = get_child(-1).get_child(0)
			soft.set("length", 0.6)
			soft.set("spring_constant", 15.0)
			soft.set("damping", 1.0)
			fast_motion = true
			movers.assign(get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D))
			cam.position = Vector3(0, 0, 4.0)
		"grid_lod":
			# many objects, camera dollying, LOD on, physics off
			build_grid(12, 32, true, false)
			dolly = true
		"grid_physics":
			# many moving objects, static camera, LOD off
			build_grid(12, 32, false, true)
			movers.assign(get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D))
			place_grid_camera(24.0)
		"grid_all":
			# both of the above: closest to real-world use
			build_grid(12, 32, true, true)
			movers.assign(get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D))
			dolly = true
		_:
			push_error("unknown scenario: " + scenario)
			get_tree().quit(1)
	load_ms = (Time.get_ticks_usec() - t0) / 1000.0


func build_grid(n: int, shells: int, lod: bool, physics: bool) -> void:
	for x: int in n:
		for z: int in n:
			add_furry(Vector3((x - n / 2.0) * 2.5, 0, (z - n / 2.0) * 2.5), 0.8, 16, 8, shells, lod, physics)
	place_grid_camera(24.0)


func place_grid_camera(dist: float) -> void:
	cam.position = Vector3(0, dist * 0.6, dist)
	cam.look_at(Vector3.ZERO)


func add_furry(pos: Vector3, radius: float, segs: int, rings: int, shells: int, lod: bool, physics: bool) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = segs
	sphere.rings = rings
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = sphere
	mi.position = pos
	var fur: Node = FUR.new()
	fur.set("seed", 1234)
	fur.set("number_of_shells", shells)
	fur.set("length", 0.25)
	fur.set("density", 1.0)
	fur.set("lod_enabled", lod)
	fur.set("lod_min_distance", 3.0)
	fur.set("lod_max_distance", 45.0)
	fur.set("physics_enabled", physics)
	mi.add_child(fur)
	add_child(mi)


func _physics_process(_delta: float) -> void:
	physics_start = Time.get_ticks_usec()
	tick += 1
	for i: int in movers.size():
		var m: Node3D = movers[i]
		if fast_motion:
			m.position.x = sin(tick * 0.25) * 1.5
			m.rotation.z = sin(tick * 0.2) * 2.0
		else:
			m.position.y = sin(tick * 0.08 + i) * 0.6
			m.rotation.y = sin(tick * 0.05 + i) * 1.5
	# screenshots are tied to a physics tick so that physics state is comparable between runs
	if shot_path != "" and tick == 120:
		get_viewport().get_texture().get_image().save_png(shot_path)


func _process(_delta: float) -> void:
	# process_usec / physics_usec hold the totals for the previous frame
	var prev_process_ms: float = process_usec / 1000.0
	var prev_physics_ms: float = physics_usec / 1000.0
	physics_usec = 0
	process_start = Time.get_ticks_usec()
	frame += 1
	if dolly:
		place_grid_camera(26.0 + 20.0 * sin(frame * TAU / 300.0))

	var now: int = Time.get_ticks_usec()
	if frame > WARMUP:
		var vp: RID = get_viewport().get_viewport_rid()
		samples["frame_ms"].append((now - last_usec) / 1000.0)
		samples["gpu_ms"].append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		samples["render_cpu_ms"].append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		samples["script_process_ms"].append(prev_process_ms)
		samples["script_physics_ms"].append(prev_physics_ms)
		samples["draw_calls"].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	last_usec = now

	if frame >= WARMUP + FRAMES:
		finish()


func finish() -> void:
	var result: Dictionary = {
		"scenario": scenario,
		"frames": FRAMES,
		"load_ms": load_ms,
		"texture_mem_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	}
	for key: String in samples:
		var v: Array = samples[key]
		v.sort()
		var sum: float = 0.0
		for x: float in v:
			sum += x
		result[key] = {"mean": sum / v.size(), "median": v[v.size() / 2], "p95": v[int(v.size() * 0.95)]}
	var json: String = JSON.stringify(result, "  ")
	if out_path != "":
		var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(json)
		f.close()
	print(json)
	get_tree().quit()
