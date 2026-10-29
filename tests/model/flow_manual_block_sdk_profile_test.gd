extends Node

const FIXTURE_ROOT: String = "res://tests/fixtures/manual_block_sdk"
const PACKAGE_ID: String = "manual_output"
const AUTHORING_ID: String = "manual_output:output"
const TEMP_DIR_PATH: String = "res://.godot/flujo_tests"
const TEMP_RESOURCE_PATH: String = TEMP_DIR_PATH + "/manual_sdk_block.tres"
const TEMP_SCENE_PATH: String = TEMP_DIR_PATH + "/manual_sdk_scene.tscn"
const TEST_MESSAGE: String = "D1 manual package persistence"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	var entry: FlowEditorBlockCatalogEntry = _test_manual_pipeline()
	if entry != null:
		var block: FlowBlock = _test_factory_identity(entry)
		if block != null:
			_test_resource_round_trip(block)
			_test_graph_duplication(block)
			_test_packed_scene_round_trip(block)
	_cleanup()
	_finish()


func _test_manual_pipeline() -> FlowEditorBlockCatalogEntry:
	var discovery: FlowPackageManifestDiscoveryResult = FlowPackageManifestLoader.new().discover(FIXTURE_ROOT)
	if not _check(not discovery.has_errors(), "The manual package root discovers without diagnostics."):
		return null
	if not _check(discovery.manifests.size() == 1, "The manual SDK root exposes exactly one package."):
		return null
	var manifest: FlowPackageManifest = discovery.manifests[0]
	_check(manifest.package_id == PACKAGE_ID, "The package ID matches its directory.")
	if not _check(manifest.blocks.size() == 1, "The canonical D1 package contains exactly one block descriptor."):
		return null
	var descriptor: FlowExternalBlockDescriptor = manifest.blocks[0]
	_check(descriptor.global_type_id() == AUTHORING_ID, "The authoring identity uses package_id:type_id.")
	_check(descriptor.script_path == "block.gd", "The script path remains package-relative.")
	_check(descriptor.display_name == "Manual Output", "The visible name comes from manifest metadata.")

	var validation: FlowPackageManifestScriptValidationResult = FlowExternalBlockScriptValidator.new().validate(
		manifest,
		FIXTURE_ROOT.path_join(PACKAGE_ID)
	)
	_check(not validation.has_errors(), "The handwritten external script validates.")
	_check(validation.valid_descriptors.size() == 1, "Exactly one handwritten descriptor remains authorable.")

	var results: Dictionary = {PACKAGE_ID: validation}
	var catalog: FlowEditorBlockCatalog = FlowEditorBlockCatalog.combine(discovery, results)
	var entry: FlowEditorBlockCatalogEntry = catalog.find(AUTHORING_ID)
	_check(entry != null, "The handwritten package appears in the combined catalog.")
	if entry != null:
		_check(entry.is_external(), "The handwritten package remains an external catalog entry.")
	return entry


func _test_factory_identity(entry: FlowEditorBlockCatalogEntry) -> FlowBlock:
	var factory: FlowExternalBlockFactory = FlowExternalBlockFactory.new()
	var package_path: String = FIXTURE_ROOT.path_join(PACKAGE_ID)
	var first: FlowExternalBlockCreationResult = factory.create(entry, package_path)
	var second: FlowExternalBlockCreationResult = factory.create(entry, package_path)
	if not _check(first.block != null and not first.has_errors(), "The manual catalog entry creates through the external factory."):
		return null
	_check(second.block != null and not second.has_errors(), "The same manual entry can be created again independently.")
	var block: FlowBlock = first.block
	_check(block is FlowOutputBlock, "The manual block satisfies the shared FlowOutputBlock contract.")
	_check(block.get_script().resource_path.ends_with("/tests/fixtures/manual_block_sdk/manual_output/block.gd"),
		"The created instance retains the external package script.")
	_check(FlowId.is_valid(block.get_internal_id()), "The factory-created manual block has a valid persistent ID.")
	_check(block.display_name == "Manual Output", "The factory initializes the descriptor display name.")
	block.set("message", TEST_MESSAGE)
	var output: FlowOutputBlock = block as FlowOutputBlock
	_check(output != null and output.get_output_message() == TEST_MESSAGE, "The external block exposes deterministic output through the shared contract.")
	if second.block != null:
		_check(second.block != block, "Repeated creation returns a different object.")
		_check(second.block.get_internal_id() != block.get_internal_id(), "Repeated creation returns a different persistent ID.")
	return block


func _test_resource_round_trip(block: FlowBlock) -> void:
	_ensure_temp_dir()
	var original_id: String = block.get_internal_id()
	var status: Error = ResourceSaver.save(block, ProjectSettings.globalize_path(TEMP_RESOURCE_PATH))
	if not _check(status == OK, "ResourceSaver stores the handwritten external block."):
		return
	var loaded_resource: Resource = ResourceLoader.load(TEMP_RESOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(loaded_resource is FlowBlock, "ResourceSaver reload returns a FlowBlock."):
		return
	var loaded: FlowBlock = loaded_resource as FlowBlock
	_check(loaded is FlowOutputBlock, "ResourceSaver reload preserves the external output contract.")
	_check(loaded.get_script().resource_path.ends_with("/tests/fixtures/manual_block_sdk/manual_output/block.gd"),
		"ResourceSaver reload preserves the concrete external script.")
	_check(loaded.get_internal_id() == original_id, "ResourceSaver reload preserves the persistent block ID.")
	_check(String(loaded.get("message")) == TEST_MESSAGE, "ResourceSaver reload preserves the exported message.")


func _test_graph_duplication(block: FlowBlock) -> void:
	var graph: FlowGraph = _graph_with_block(block)
	var copy: FlowGraph = graph.duplicate_with_new_ids()
	if not _check(copy.processes.size() == 1 and copy.processes[0] != null, "Graph duplication preserves the process containing the external block."):
		return
	if not _check(copy.processes[0].blocks.size() == 1 and copy.processes[0].blocks[0] != null, "Graph duplication preserves the external block position."):
		return
	var copied: FlowBlock = copy.processes[0].blocks[0]
	_check(copied is FlowOutputBlock, "Graph duplication preserves the external output contract.")
	_check(copied.get_script().resource_path.ends_with("/tests/fixtures/manual_block_sdk/manual_output/block.gd"),
		"Graph duplication preserves the concrete external script.")
	_check(copied.get_internal_id() != block.get_internal_id(), "Graph duplication renews the external block ID.")
	_check(String(copied.get("message")) == TEST_MESSAGE, "Graph duplication preserves the external block field.")


func _test_packed_scene_round_trip(block: FlowBlock) -> void:
	_ensure_temp_dir()
	var graph: FlowGraph = _graph_with_block(block)
	var original_id: String = block.get_internal_id()
	var root: Node = Node.new()
	root.name = "ManualSdkRoot"
	var controller: PVController = PVController.new()
	controller.name = "Controller"
	controller.flow_graph = graph
	root.add_child(controller)
	controller.owner = root

	var packed: PackedScene = PackedScene.new()
	var pack_status: Error = packed.pack(root)
	if not _check(pack_status == OK, "PackedScene accepts a controller containing the handwritten external block."):
		root.free()
		return
	var save_status: Error = ResourceSaver.save(packed, ProjectSettings.globalize_path(TEMP_SCENE_PATH))
	root.free()
	if not _check(save_status == OK, "PackedScene stores the handwritten external block."):
		return

	var loaded_scene: PackedScene = ResourceLoader.load(TEMP_SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if not _check(loaded_scene != null, "PackedScene reload succeeds."):
		return
	var instance: Node = loaded_scene.instantiate()
	if not _check(instance != null, "PackedScene instantiates after reload."):
		return
	var loaded_controller: PVController = instance.get_node_or_null("Controller") as PVController
	if not _check(loaded_controller != null and loaded_controller.flow_graph != null, "Reloaded scene preserves the controller and graph."):
		instance.free()
		return
	var loaded_process: FlowProcess = loaded_controller.flow_graph.processes[0]
	if not _check(loaded_process != null and loaded_process.blocks.size() == 1, "Reloaded graph preserves the external block position."):
		instance.free()
		return
	var loaded_block: FlowBlock = loaded_process.blocks[0]
	_check(loaded_block is FlowOutputBlock, "PackedScene reload preserves the external output contract.")
	_check(loaded_block.get_script().resource_path.ends_with("/tests/fixtures/manual_block_sdk/manual_output/block.gd"),
		"PackedScene reload preserves the concrete external script.")
	_check(loaded_block.get_internal_id() == original_id, "PackedScene reload preserves the persistent block ID.")
	_check(String(loaded_block.get("message")) == TEST_MESSAGE, "PackedScene reload preserves the exported message.")
	instance.free()


func _graph_with_block(block: FlowBlock) -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var process: FlowProcess = FlowProcess.new()
	process.process_type = FlowProcess.ProcessType.READY
	process.blocks = [block]
	graph.processes = [process]
	return graph


func _ensure_temp_dir() -> void:
	var absolute: String = ProjectSettings.globalize_path(TEMP_DIR_PATH)
	if not DirAccess.dir_exists_absolute(absolute):
		DirAccess.make_dir_recursive_absolute(absolute)


func _cleanup() -> void:
	for path: String in [TEMP_RESOURCE_PATH, TEMP_SCENE_PATH]:
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	var temp_dir: String = ProjectSettings.globalize_path(TEMP_DIR_PATH)
	if DirAccess.dir_exists_absolute(temp_dir):
		var access: DirAccess = DirAccess.open(temp_dir)
		if access != null and access.get_files().is_empty() and access.get_directories().is_empty():
			DirAccess.remove_absolute(temp_dir)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Manual block SDK profile test passed")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	get_tree().quit(1)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
	return condition
