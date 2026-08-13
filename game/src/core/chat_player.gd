class_name ChatPlayer
extends RefCounted
## chat.json 스크립트 순회. require 플래그 게이트, choices의 set 플래그 적용.

var _nodes: Dictionary
var _cur: String
var _state: Node

func _init(thread: Dictionary, state: Node) -> void:
	_nodes = thread["nodes"]
	_cur = thread["start"]
	_state = state

func current() -> Dictionary:
	return _nodes[_cur]

func at_end() -> bool:
	var n := current()
	return not n.has("next") and not n.has("choices")

func advance() -> bool:
	var n := current()
	if not n.has("next"):
		return false
	var nxt: String = n["next"]
	var req := String(_nodes[nxt].get("require", ""))
	if req != "" and not _state.has_flag(req):
		return false  # 플래그 충족 전 대기 (메신저가 flag_changed에서 재시도)
	_cur = nxt
	for f in current().get("set", []):
		_state.set_flag(f)
	return true

func choose(idx: int) -> void:
	var c: Dictionary = current()["choices"][idx]
	for f in c.get("set", []):
		_state.set_flag(f)
	_cur = c["next"]
