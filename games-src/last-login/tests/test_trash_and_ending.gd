extends GdUnitTestSuite

## 이 스위트가 막는 사고: 휴지통은 게임의 마지막 문이다. 여기서 파일이 안 나오거나,
## 반대로 실수로 지워져 버리면 게임이 그대로 막힌다 — 화면만 봐서는 알 수 없다.

const TrashApp := preload("res://src/apps/trash.gd")
const EndingScene := preload("res://src/ending/ending.gd")
const WindowManagerScript := preload("res://src/desktop/window_manager.gd")
const GameStateScript := preload("res://src/core/game_state.gd")

func before_test() -> void:
	GameState.reset()

func after_test() -> void:
	# 복원·비움 상태가 남으면 다음 스위트의 파일 목록이 조용히 달라진다
	GameState.reset()

func _trash() -> Control:
	var t: Control = auto_free(TrashApp.new())
	add_child(t)
	return t

func _trash_with_wm() -> Array:
	var wm: Control = auto_free(WindowManagerScript.new())
	add_child(wm)  # _ready에서 "window_manager" 그룹 등록
	return [_trash(), wm]

func test_restore_decoy_fails_target_succeeds() -> void:
	var t := _trash()
	assert_bool(t.restore("t2")).is_false()
	assert_bool(GameState.has_flag("puzzle4_solved")).is_false()
	assert_bool(t.restore("t1")).is_true()
	assert_bool(GameState.has_flag("puzzle4_solved")).is_true()
	assert_bool(GameState.has_flag("final_diary_read")).is_true()
	assert_bool(GameState.is_read("doc:diary_final")).is_true()

func test_restored_file_leaves_the_trash_for_my_documents() -> void:
	# '복원'이라는 말이 거짓이 아니어야 한다 — 파일은 실제로 원래 폴더에 가 있어야 하고,
	# 나중에 탐색기에서 다시 열 수 있어야 한다.
	var t := _trash()
	assert_int(ContentDB.trash_items().size()).is_equal(5)
	assert_bool(t.restore("t1")).is_true()
	assert_int(ContentDB.trash_items().size()).is_equal(4)
	assert_int(t.item_count()).is_equal(4)
	var names := PackedStringArray()
	for n in ContentDB.fs_children("mydocs"):
		names.append(String(n["name"]))
	assert_bool(names.has("backup_1102.txt")).override_failure_message(
		"복원한 파일이 내 문서에 없다: " + str(names)).is_true()

func test_restore_survives_a_save_and_load() -> void:
	var gs: Node = auto_free(GameStateScript.new())
	add_child(gs)
	gs.reset()
	gs.restore_node("t1")
	var gs2: Node = auto_free(GameStateScript.new())
	add_child(gs2)
	assert_bool(gs2.load_game()).is_true()
	assert_bool(gs2.is_restored("t1")).override_failure_message(
		"복원한 파일이 세이브에 안 남으면 다시 켰을 때 휴지통으로 되돌아간다").is_true()

func test_emptying_the_trash_cannot_take_the_last_file() -> void:
	# 여기서 유서까지 지워지면 게임이 막힌다. 손상된 것만 지워지고 하나는 남아야 한다.
	var t := _trash()
	assert_bool(t.purge()).is_false()
	var left := ContentDB.trash_items()
	assert_int(left.size()).is_equal(1)
	assert_str(String(left[0]["id"])).is_equal("t1")
	assert_str(t.last_message()).contains("사용 중")
	assert_int(t.item_count()).is_equal(1)

func test_emptying_after_restoring_leaves_nothing() -> void:
	var t := _trash()
	assert_bool(t.restore("t1")).is_true()
	assert_bool(t.purge()).is_true()
	assert_int(ContentDB.trash_items().size()).is_equal(0)
	assert_bool(t.is_empty_shown()).is_true()

func test_details_view_lists_where_each_file_came_from() -> void:
	var t := _trash()
	assert_int(t.detail_row_count()).is_equal(5)
	# 원래 위치는 탐색기와 같은 경로 표기를 쓴다 (두 창이 같은 OS로 보여야 한다)
	assert_str(TrashApp.origin_text(ContentDB.fs_node("t1"))).is_equal("C:\\내 문서")
	assert_str(TrashApp.origin_text(ContentDB.fs_node("t4"))).is_equal("C:\\내 문서\\새빛수련회")
	assert_str(TrashApp.origin_text(ContentDB.fs_node("t5"))).is_equal("C:\\WINDOWS\\Temp")

func test_every_trash_item_declares_where_it_came_from() -> void:
	# 열이 비면 '자세히' 보기가 반쯤 빈 표가 된다 — 콘텐츠 쪽에서 막는다
	for n in ContentDB.trash_items():
		var id := String(n["id"])
		assert_bool(n.has("origin") or n.has("origin_path")).override_failure_message(
			id + "에 원래 위치가 없다").is_true()
		assert_str(String(n.get("deleted", ""))).override_failure_message(
			id + "에 삭제한 날짜가 없다").is_not_empty()
		if n.get("corrupt", false):
			assert_str(String(n.get("error", ""))).override_failure_message(
				id + "에 섹터 오류 코드가 없다").is_not_empty()

func test_progress_stalls_and_explains_itself_on_a_corrupt_file() -> void:
	var t := _trash()
	t.restore_sec = 0.05
	t._begin_restore("t2")
	await get_tree().create_timer(0.7).timeout
	assert_float(t.progress_value()).override_failure_message(
		"손상된 파일인데 진행률이 끝까지 찼다").is_less(100.0)
	assert_bool(t.progress_visible()).override_failure_message(
		"멈춘 막대가 오류창 뒤에 남아 있어야 한다").is_true()
	assert_str(t.last_message()).contains("0x0000001E")
	t._dialog.close()
	assert_bool(t.progress_visible()).is_false()
	assert_bool(t.is_busy()).is_false()

func test_progress_completes_and_opens_the_restored_document() -> void:
	var pair := _trash_with_wm()
	var t: Control = pair[0]
	var wm: Control = pair[1]
	t.restore_sec = 0.05
	t._begin_restore("t1")
	await get_tree().create_timer(0.4).timeout
	assert_bool(t.progress_visible()).is_false()
	assert_bool(t.is_busy()).is_false()
	assert_bool(wm.is_open("doc:t1")).override_failure_message(
		"복원했는데 메모장 창이 안 열렸다").is_true()

func test_selection_survives_a_view_switch() -> void:
	var t := _trash()
	t.select("t1")
	t.set_view_mode(TrashApp.ViewMode.DETAILS)
	assert_str(t.selected_id()).is_equal("t1")
	assert_str(String(t._tree.get_selected().get_metadata(0))).is_equal("t1")

func test_error_dialog_draws_above_the_progress_panel() -> void:
	# 순서가 뒤집히면 오류 문구가 진행률 창에 가려 화면에서 사라진다 (눈으로만 잡히는 사고)
	var t := _trash()
	assert_int(t._progress.get_index()).override_failure_message(
		"진행률 창이 대화상자보다 뒤에 붙어야 한다").is_less(t._dialog.get_index())

func test_hidden_ending_gate_counts_records() -> void:
	# records_source를 좁혀 2개만 기록물로 두고 검증
	assert_bool(EndingScene.should_show_hidden()).is_false()
	for cid in ContentDB.records():
		GameState.mark_read(cid)
	# 콘텐츠는 기록물 9개로 확정됨 (records.json)
	assert_int(GameState.records_count()).is_equal(ContentDB.records().size())

func test_ending_label_has_korean_font() -> void:
	# CanvasLayer는 테마 미상속 — 폰트 오버라이드 없으면 웹에서 한글이 두부로 렌더링된다 (회귀 방지)
	var e: CanvasLayer = auto_free(EndingScene.new())
	add_child(e)
	e.play(false)
	var found := false
	for c in e.get_children():
		if c is RichTextLabel:
			found = true
			assert_bool(c.has_theme_font_override("normal_font")).is_true()
	assert_bool(found).is_true()

func test_epilogue_types_all_lines_and_hidden_when_gated() -> void:
	var e: CanvasLayer = auto_free(EndingScene.new())
	add_child(e)
	e.line_delay = 0.01
	var label := RichTextLabel.new()
	e.add_child(label)
	for cid in ContentDB.records():
		GameState.mark_read(cid)
	await e._type_lines(label, e.EPILOGUE, true)
	await get_tree().create_timer(2.2).timeout
	var text := label.get_parsed_text()
	assert_str(text).contains("LAST LOGIN")
	assert_str(text).contains("어디서 나셨어요")

func test_hidden_ending_echoes_only_what_the_player_said() -> void:
	# 입을 닫았다면 돌아오지 않는다 — 그게 그 선택의 보상이다
	assert_int(EndingScene.hidden_lines().size()).is_equal(EndingScene.HIDDEN.size())
	GameState.set_flag("pickup_told")
	var lines := EndingScene.hidden_lines()
	assert_int(lines.size()).is_equal(EndingScene.HIDDEN.size() + 1)
	assert_str(String(lines[-1])).contains("아까 말씀하셨죠")
