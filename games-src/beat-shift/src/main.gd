extends Node2D
## 세션 상태 머신 + 리듬 판정 루프. 박자의 진실은 Conductor.

var scene_stage: ForgeScene
var hud: Hud
var overlay: Overlay
var world: Node2D
var rng := RandomNumberGenerator.new()

var section := 0
var judge: NoteJudge
var _note_times: Array = []
var _cue_cursor := 0.0
var _jingle_done := false
var _anvil_idx := 0
var _paused := false
var _dying := false

func _ready() -> void:
	rng.randomize()
	world = Node2D.new()
	add_child(world)
	scene_stage = ForgeScene.new()
	world.add_child(scene_stage)
	hud = Hud.new()
	add_child(hud)
	overlay = Overlay.new()
	add_child(overlay)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	if GameState.quick_restart:
		GameState.quick_restart = false
		_begin_run()
	else:
		GameState.phase = GameState.Phase.TITLE
		overlay.show_title()

func _update_layout() -> void:
	# expand 스트레치로 넓어진 화면에서 270×480 플레이 영역을 중앙에 둔다
	var vs := get_viewport_rect().size
	var off := Vector2(
		floorf(maxf((vs.x - Tuning.VIEW_W) * 0.5, 0.0)),
		floorf(maxf((vs.y - Tuning.VIEW_H) * 0.5, 0.0))
	)
	world.position = off
	hud.offset = off
	overlay.offset = off

func _begin_run() -> void:
	overlay.clear()
	GameState.start_run()
	section = 0
	_anvil_idx = 0
	_start_section()

func _start_section() -> void:
	Conductor.start_section(section)
	var beats := Patterns.section_notes(Patterns.tier_for_section(section), rng)
	_note_times = []
	for b in beats:
		_note_times.append(ConductorMath.time_from_beats(Tuning.INTRO_BEATS + float(b), Conductor.bpm))
	judge = NoteJudge.new(_note_times, Tuning.PERFECT_WIN, Tuning.GOOD_WIN)
	_cue_cursor = 0.0
	_jingle_done = false

func _process(_delta: float) -> void:
	if GameState.phase != GameState.Phase.PLAYING or _paused:
		return
	var t := Conductor.song_time()
	for m in judge.advance(t + Tuning.INPUT_OFFSET):
		GameState.register_fail("miss")
		scene_stage.on_result("miss", m)
		Sfx.play("miss")
	if GameState.is_dead():
		_game_over()
		return
	var lead := ConductorMath.time_from_beats(Tuning.CUE_LEAD_BEATS, Conductor.bpm)
	for nt in ConductorMath.due_cues(_note_times, _cue_cursor, t, lead):
		scene_stage.spawn_cue(nt, float(nt) - lead)
	_cue_cursor = t
	var beats := Conductor.song_beats()
	if not _jingle_done and beats >= Tuning.INTRO_BEATS + Tuning.NOTE_BEATS:
		_jingle_done = true
		var bonus := GameState.register_section_clear(section)
		Sfx.play("jingle")
		hud.flash("TEMPO UP  +%d" % bonus)
	if beats >= Tuning.SECTION_BEATS:
		section += 1
		_start_section()
	hud.set_groove(GameState.groove / Tuning.GROOVE_MAX)
	hud.set_mult(GameState.mult)
	scene_stage.set_heat(GameState.groove / Tuning.GROOVE_MAX)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("tap"):
		return
	if _paused:
		_resume()
		return
	match GameState.phase:
		GameState.Phase.TITLE:
			_begin_run()
		GameState.Phase.PLAYING:
			_on_tap()
		GameState.Phase.GAME_OVER:
			if not _dying:
				GameState.quick_restart = true
				get_tree().reload_current_scene()

func _on_tap() -> void:
	var r := judge.on_tap(Conductor.song_time() + Tuning.INPUT_OFFSET)
	match r.result:
		"perfect", "good":
			GameState.register_hit(r.result)
			scene_stage.on_result(r.result, r.note_time)
			if r.result == "perfect":
				Sfx.play("anvil_%d" % (_anvil_idx % 4 + 1))
				_anvil_idx += 1
			else:
				Sfx.play("good")
		"stray":
			GameState.register_fail("stray")
			scene_stage.on_result("stray", -1.0)
			Sfx.play("whiff")
	if GameState.is_dead():
		_game_over()

func _game_over() -> void:
	_dying = true
	var was_best := GameState.best
	GameState.end_run()
	Conductor.stop()
	scene_stage.clear_cues()
	Sfx.play("gameover")
	Engine.time_scale = Tuning.DEATH_SLOWMO
	var timer := get_tree().create_timer(Tuning.DEATH_SLOWMO_SEC, true, false, true)
	timer.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_dying = false
		overlay.show_game_over(GameState.score(), GameState.best, GameState.best > was_best)
	)

func _resume() -> void:
	# 박자 어긋남 방지 — 현재 마디 처음부터 다시 (루프 = 1마디라 시킹 불필요).
	# 노트 목록을 미처리분으로 재구성하고 큐 커서를 lead만큼 되돌려
	# 유령 큐(이미 처리된 노트 재큐)와 무음 미스(마디 초입 노트 큐 누락)를 막는다.
	_paused = false
	overlay.clear()
	var bar := int(floor(Conductor.song_beats() / float(Tuning.BEATS_PER_BAR)))
	var bar_start := ConductorMath.time_from_beats(float(bar * Tuning.BEATS_PER_BAR), Conductor.bpm)
	var lead := ConductorMath.time_from_beats(Tuning.CUE_LEAD_BEATS, Conductor.bpm)
	scene_stage.clear_cues()
	_note_times = judge.remaining_after(bar_start)
	judge = NoteJudge.new(_note_times, Tuning.PERFECT_WIN, Tuning.GOOD_WIN)
	_cue_cursor = bar_start - lead
	Conductor.resume_at_bar(bar)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameState.phase == GameState.Phase.PLAYING and not _paused:
		_paused = true
		Conductor.stop()
		overlay.show_paused()
