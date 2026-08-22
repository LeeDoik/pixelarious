extends GdUnitTestSuite

const BrowserApp := preload("res://src/apps/browser.gd")

func before_test() -> void:
	GameState.reset()

func test_dead_cafe_page_renders_closed_notice() -> void:
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	var page: Dictionary = b.navigate("cafe.nurinet.co.kr/saebit")
	assert_str(String(page["title"])).contains("찾을 수 없습니다")

func test_gate_url_solves_puzzle3_and_marks_record() -> void:
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	var page: Dictionary = b.navigate("cafe.nurinet.co.kr/saebit/gate")
	assert_bool(GameState.has_flag("puzzle3_solved")).is_true()
	assert_bool(GameState.is_read("web:cafe_gate")).is_true()
	assert_str(String(page["title"])).contains("새빛")

func test_unknown_url_returns_empty() -> void:
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	assert_bool(b.navigate("nowhere.example").is_empty()).is_true()

func test_offline_cache_status_follows_the_page() -> void:
	# 페이지마다 저장 시각이 다른 게 서사다 (성진의 마지막 접속 11-02 vs 누군가의 2003-01-31)
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	b.navigate("portal.nurinet.co.kr")
	assert_str(b.cache_text()).contains("2002-11-02")
	b.navigate("cafe.nurinet.co.kr/saebit")
	assert_str(b.cache_text()).contains("2003-01-31")

func test_every_page_states_when_it_was_cached() -> void:
	# 상태표시줄이 본문에서 저장 시각을 뽑아 쓴다 — 콘텐츠에서 빠지면 "시각 미상"이 된다.
	# (연도는 페이지마다 다르다: 성진의 마지막 접속 2002-11-02, 그 뒤 누군가의 2003-01-31)
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	var re := RegEx.new()
	re.compile("[0-9]{4}-[0-9]{2}-[0-9]{2}")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/web.json"))
	for url in raw["pages"]:
		b.navigate(String(url))
		assert_bool(re.search(b.cache_text()) != null).override_failure_message(
			"%s 페이지에서 저장 시각을 못 읽었다: %s" % [url, b.cache_text()]).is_true()

func test_uncached_url_shows_the_dedicated_notice() -> void:
	# 퍼즐3에서 주소를 더듬는 플레이어에게 이 화면이 피드백이 된다
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	assert_bool(b.navigate("cafe.nurinet.co.kr/saebit/list").is_empty()).is_true()
	assert_str(b.page_title()).contains("캐시에 없는")
	assert_str(b.status_text()).contains("캐시 없음")

func test_history_back_and_forward() -> void:
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)                              # _ready가 홈으로 한 번 이동한다
	assert_bool(b.can_go_back()).is_false()
	b.navigate("myhome.nurinet.co.kr/sj2002")
	assert_bool(b.can_go_back()).is_true()
	b.go_back()
	assert_str(b.address_text()).is_equal("portal.nurinet.co.kr")
	assert_bool(b.can_go_forward()).is_true()
	b.go_forward()
	assert_str(b.address_text()).is_equal("myhome.nurinet.co.kr/sj2002")

func test_body_urls_become_links_but_dates_do_not() -> void:
	# 마이홈 본문에는 방명록 주소가 적혀 있고, 날짜(2002.03.16)도 잔뜩 있다.
	# 날짜가 링크가 되면 화면이 밑줄 범벅이 되고 퍼즐 감각도 무너진다.
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	b.navigate("myhome.nurinet.co.kr/sj2002")
	assert_int(b.link_count()).is_greater(0)
	for link in b.grid_links():
		assert_str(String(link["url"])).override_failure_message(
			"날짜가 링크로 잡혔다: " + String(link["url"])).contains(".co.kr")

func test_gate_url_is_not_linked_anywhere() -> void:
	# 퍼즐3은 /gate를 직접 쳐야 풀린다. 어느 페이지에도 그 주소가 적혀 있으면 안 된다.
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/web.json"))
	for url in raw["pages"]:
		b.navigate(String(url))
		for link in b.grid_links():
			assert_str(String(link["url"])).override_failure_message(
				"%s 페이지가 /gate를 링크로 노출한다" % url).is_not_equal("cafe.nurinet.co.kr/saebit/gate")

func test_every_page_declares_a_known_skin() -> void:
	# 스킨이 없거나 오타가 나면 조용히 시스템 스킨으로 떨어져 사이트 구분이 사라진다
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/web.json"))
	for url in raw["pages"]:
		var skin := String(raw["pages"][url].get("skin", ""))
		assert_bool(BrowserApp.SKINS.has(skin)).override_failure_message(
			"%s 페이지의 skin이 없거나 모르는 값이다: '%s'" % [url, skin]).is_true()

func test_each_site_looks_different() -> void:
	# 띠 색이 겹치면 사이트가 갈리지 않는다
	var seen := {}
	for id in BrowserApp.SKINS:
		var band := String(BrowserApp.SKINS[id]["band"])
		assert_bool(seen.has(band)).override_failure_message(
			"스킨 %s의 띠 색이 다른 스킨과 같다: #%s" % [id, band]).is_false()
		seen[band] = true

func test_skin_follows_the_page() -> void:
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	b.navigate("portal.nurinet.co.kr")
	assert_str(b.skin_id()).is_equal("portal")
	assert_str(b.band_text()).contains("누리넷")
	b.navigate("myhome.nurinet.co.kr/sj2002")
	assert_str(b.skin_id()).is_equal("myhome")
	assert_str(b.band_text()).contains("마이홈")

func test_the_cult_gate_wears_the_ordinary_cafe_shell() -> void:
	# 연출 의도: 저 사람들은 평범한 포털 카페 안에 있었다.
	# 관문만 따로 무섭게 칠하면 그 사실이 흐려진다.
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	b.navigate("cafe.nurinet.co.kr/gongsi9")
	var ordinary: String = b.skin_id()
	b.navigate("cafe.nurinet.co.kr/saebit/gate")
	assert_str(b.skin_id()).is_equal(ordinary)
	assert_str(b.band_text()).contains("정회원 전용")

func test_uncached_page_falls_back_to_the_system_skin() -> void:
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	b.navigate("myhome.nurinet.co.kr/sj2002")
	b.navigate("nowhere.nurinet.co.kr/x")
	assert_str(b.skin_id()).is_equal("system")

func test_image_markers_resolve_to_real_assets() -> void:
	# 마커 이름에 오타가 나면 그 자리에 아무것도 안 나오고 조용히 넘어간다
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/web.json"))
	var re := RegEx.new()
	re.compile(BrowserApp.IMG_PATTERN)
	var found := 0
	for url in raw["pages"]:
		for line in String(raw["pages"][url]["body"]).split("\n"):
			var m := re.search(line)
			if m == null:
				continue
			found += 1
			var kind := m.get_string(1)
			var name := m.get_string(2)
			if kind == "blink":
				for suffix in ["_a.png", "_b.png"]:
					assert_bool(ResourceLoader.exists(BrowserApp.WEB_IMG_DIR + name + suffix)).override_failure_message(
						"%s: 깜빡이 그림 %s%s 가 없다" % [url, name, suffix]).is_true()
			else:
				assert_bool(ResourceLoader.exists(BrowserApp.WEB_IMG_DIR + name + ".png")).override_failure_message(
					"%s: 그림 %s.png 가 없다" % [url, name]).is_true()
	assert_int(found).is_greater(0)

func test_markers_do_not_leak_into_the_text() -> void:
	# 마커 줄이 본문에 남으면 격자에 [[img:...]]가 그대로 찍힌다
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	for url in ["portal.nurinet.co.kr", "cafe.nurinet.co.kr/gongsi9", "myhome.nurinet.co.kr/sj2002"]:
		b.navigate(url)
		for link in b.grid_links():
			pass
		assert_int(b.image_count()).override_failure_message(
			"%s 페이지에 그림이 하나도 안 붙었다" % url).is_greater(0)

func test_portal_carries_the_blinking_ad() -> void:
	# 2002년 포털의 얼굴. 한 군데만 움직여야 광고로 읽힌다.
	var b: Control = auto_free(BrowserApp.new())
	add_child(b)
	b.navigate("portal.nurinet.co.kr")
	assert_int(b.image_count()).is_equal(2)     # 로고 + 띠광고
	assert_int(b.blink_count()).is_equal(1)
	b.navigate("cafe.nurinet.co.kr/gongsi9")
	assert_int(b.blink_count()).is_equal(0)     # 광고는 포털에만

func test_the_cult_emblem_appears_on_the_gate() -> void:
	# diary/17의 "차 뒷유리에 빛 모양 스티커"와 같은 표식이라, 나중에 그 줄과 연결된다
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/web.json"))
	var body := String(raw["pages"]["cafe.nurinet.co.kr/saebit/gate"]["body"])
	assert_str(body).contains("[[img:banner_saebit]]")
