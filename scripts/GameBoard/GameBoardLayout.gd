class_name GameBoardLayout
extends RefCounted

var owner: Control
var surface: Control

func attach(board_owner: Control, surface_owner: Control = null) -> void:
	owner = board_owner
	surface = surface_owner if surface_owner != null else board_owner

func build_ui() -> void:
	owner.variation_tree = owner.get_node_or_null("RootVBox/MainHBox/VariationPanel/VariationVBox/VariationTree") as GraphEdit
	owner.status_label = owner.get_node_or_null("RootVBox/MainHBox/LeftPanel/StatusLabel") as Label
	owner.black_captures_label = owner.get_node_or_null("RootVBox/MainHBox/LeftPanel/BlackCapturesLabel") as Label
	owner.white_captures_label = owner.get_node_or_null("RootVBox/MainHBox/LeftPanel/WhiteCapturesLabel") as Label
	owner.komi_input = owner.get_node_or_null("RootVBox/MainHBox/LeftPanel/KomiRow/KomiInput") as LineEdit
	owner.final_score_label = owner.get_node_or_null("RootVBox/MainHBox/LeftPanel/FinalScoreLabel") as Label
	owner.back_button = owner.get_node_or_null("RootVBox/Header/BackButton") as Button
	owner.restart_button = owner.get_node_or_null("RootVBox/Header/RestartButton") as Button
	owner.pass_button = owner.get_node_or_null("RootVBox/Header/PassButton") as Button
	owner.save_sgf_button = owner.get_node_or_null("RootVBox/Header/SaveSgfButton") as Button
	owner.load_sgf_button = owner.get_node_or_null("RootVBox/Header/LoadSgfButton") as Button
	owner.board_surface = owner.get_node_or_null("RootVBox/MainHBox/BoardPanel/BoardSurface") as Control

	owner.back_button.pressed.connect(owner._on_back_to_overworld_pressed)
	owner.restart_button.pressed.connect(owner._on_restart_pressed)
	owner.pass_button.pressed.connect(owner._on_pass_pressed)
	owner.save_sgf_button.pressed.connect(owner._save_sgf)
	owner.load_sgf_button.pressed.connect(owner._load_sgf)
	owner.variation_tree.node_selected.connect(owner._on_variation_tree_item_selected)

	_build_file_dialogs(owner)

func _build_file_dialogs(board_owner: Control) -> void:
	board_owner.save_dialog = FileDialog.new()
	board_owner.save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	board_owner.save_dialog.access = FileDialog.ACCESS_USERDATA
	board_owner.save_dialog.filters = ["*.sgf ; SGF files"]
	board_owner.save_dialog.title = "Save SGF game"
	board_owner.save_dialog.file_selected.connect(board_owner._on_save_dialog_file_selected)
	board_owner.add_child(board_owner.save_dialog)

	board_owner.load_dialog = FileDialog.new()
	board_owner.load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	board_owner.load_dialog.access = FileDialog.ACCESS_USERDATA
	board_owner.load_dialog.filters = ["*.sgf ; SGF files"]
	board_owner.load_dialog.title = "Load SGF game"
	board_owner.load_dialog.file_selected.connect(board_owner._on_load_dialog_file_selected)
	board_owner.add_child(board_owner.load_dialog)
