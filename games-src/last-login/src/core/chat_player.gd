class_name ChatPlayer
extends RefCounted
## chat.json 스크립트 순회. require 게이트, choices의 set 플래그 적용,
## 그리고 말해주기 우회(detour) — 본선 자리를 스택에 두고 응답 노드로 새었다가 돌아온다.

var _nodes: Dictionary
var _cur: String
var _state: Node
var _stack: Array[String] = []   # 우회 전 본선 위치 (겹쳐 새는 일은 없지만 스택으로 둔다)

func _init(thread: Dictionary, state: Node) -> void:
	_nodes = thread["nodes"]
	_cur = thread["start"]
	_state = state

func current() -> Dictionary:
	return _nodes[_cur]

func current_id() -> String:
	return _cur

func at_end() -> bool:
	var n := current()
	return not n.has("next") and not n.has("choices")

## require를 푼다 — 대화·힌트·말해주기·엔딩이 전부 이 한 문법을 쓴다.
##   "flag"            플래그
##   "read:<cid>"      열람 기록
##   "told:<cid>"      말해준 것 (플래그 이름 그대로)
##   "!x"              부정
##   ["a", "b"]        전부
##   {"any": ["a","b"]} 하나라도
static func open(req, state: Node) -> bool:
	if req is Array:
		for r in req:
			if not open(r, state):
				return false
		return true
	if req is Dictionary:
		for r in req.get("any", []):
			if open(r, state):
				return true
		return false
	var s := String(req)
	if s == "":
		return true
	if s.begins_with("!"):
		return not open(s.substr(1), state)
	if s.begins_with("read:"):
		return state.is_read(s.trim_prefix("read:"))
	return state.has_flag(s)

func gate_open(req) -> bool:
	return open(req, _state)

## 다음 노드의 자물쇠가 열려 있나 — 본선이 퍼즐 앞에 멈춰 있는지 메신저가 이걸로 안다
func next_gate_open() -> bool:
	var n := current()
	if not n.has("next"):
		return false
	return gate_open(_nodes[n["next"]].get("require", ""))

func advance() -> bool:
	var n := current()
	if not n.has("next"):
		return false
	if not next_gate_open():
		return false  # 플래그 충족 전 대기 (메신저가 flag_changed에서 재시도)
	_cur = n["next"]
	_apply_set()
	return true

func choose(idx: int) -> void:
	var c: Dictionary = current()["choices"][idx]
	for f in c.get("set", []):
		_state.set_flag(f)
	_cur = c["next"]
	_apply_set()

## 본선을 제자리에 두고 응답 노드로 샌다. 응답이 끝 노드에 닿으면 pop_detour로 돌아온다.
func detour(node_id: String) -> void:
	_stack.append(_cur)
	_cur = node_id
	_apply_set()

func in_detour() -> bool:
	return not _stack.is_empty()

func pop_detour() -> bool:
	if _stack.is_empty():
		return false
	_cur = _stack.pop_back()
	return true

func _apply_set() -> void:
	for f in current().get("set", []):
		_state.set_flag(f)
