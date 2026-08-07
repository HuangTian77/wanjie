extends GdUnitTestSuite
## GdUnit4 试点最小套件：验证框架接入正确

func test_addition() -> void:
	assert_that(1 + 1).is_equal(2)

func test_script_data_available() -> void:
	var ws := WorldScriptData.new()
	assert_that(ws).is_not_null()
	assert_that(ws.id).is_equal("")

func test_bool_logic() -> void:
	assert_that(true and true).is_true()
	assert_that(not false).is_true()
