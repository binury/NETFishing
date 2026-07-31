extends SceneTree

const PROJECT_PATH := "/tmp/netfishing"
const INSTALL_PATH := "/opt/NETfishing"


func _initialize() -> void:
	var root_to_create: String = OS.get_environment("NETFISHING_TEST_CREATE_ROOT")
	if not root_to_create.is_empty():
		_create_validation_root(root_to_create)
		return
	var failures: PackedStringArray = []
	_expect(
		"external temporary directory",
		"/tmp/NETfishing-test-data",
		PlayerDataRoot.PATH_ALLOWED,
		failures,
	)
	_expect(
		"external trailing slash",
		"/tmp/NETfishing-test-data/",
		PlayerDataRoot.PATH_ALLOWED,
		failures,
	)
	_expect(
		"similar project-name sibling",
		"/tmp/netfishing-data",
		PlayerDataRoot.PATH_ALLOWED,
		failures,
	)
	_expect(
		"documents directory",
		"/home/player/Documents/NETfishing",
		PlayerDataRoot.PATH_ALLOWED,
		failures,
	)
	_expect("source project", PROJECT_PATH, PlayerDataRoot.PATH_SOURCE_PROJECT, failures)
	_expect(
		"source project child",
		PROJECT_PATH.path_join("player-data"),
		PlayerDataRoot.PATH_SOURCE_PROJECT,
		failures,
	)
	_expect(
		"installation directory",
		INSTALL_PATH,
		PlayerDataRoot.PATH_INSTALLATION,
		failures,
	)
	_expect(
		"installation child",
		INSTALL_PATH.path_join("portable-data"),
		PlayerDataRoot.PATH_INSTALLATION,
		failures,
	)
	_expect_with_references(
		"empty project reference",
		"/tmp/NETfishing-test-data",
		"",
		INSTALL_PATH,
		PlayerDataRoot.PATH_ALLOWED,
		failures,
	)
	_expect_with_references(
		"root project reference",
		"/tmp/NETfishing-test-data",
		"/",
		INSTALL_PATH,
		PlayerDataRoot.PATH_ALLOWED,
		failures,
	)
	_expect_with_references(
		"Windows component and case normalization",
		"C:\\Games\\NETfishing Data",
		"C:\\Games\\NETfishing",
		"C:\\Program Files\\NETfishing",
		PlayerDataRoot.PATH_ALLOWED,
		failures,
		true,
	)
	if failures.is_empty():
		print("PlayerDataRoot path validation: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _create_validation_root(path: String) -> void:
	var data_root := PlayerDataRoot.new()
	get_root().add_child(data_root)
	if data_root.select_new_root(path):
		print("PlayerDataRoot validation root created: ", data_root.root_path)
		quit(0)
		return
	push_error(data_root.error_message)
	quit(1)


func _expect(
	label: String,
	candidate: String,
	expected: StringName,
	failures: PackedStringArray,
) -> void:
	_expect_with_references(
		label,
		candidate,
		PROJECT_PATH,
		INSTALL_PATH,
		expected,
		failures,
	)


func _expect_with_references(
	label: String,
	candidate: String,
	project: String,
	installation: String,
	expected: StringName,
	failures: PackedStringArray,
	case_insensitive: bool = false,
) -> void:
	var actual: StringName = PlayerDataRoot.classify_candidate_path(
		candidate, project, installation, case_insensitive
	)
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [label, expected, actual])
