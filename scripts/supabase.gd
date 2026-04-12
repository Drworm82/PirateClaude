extends Node

signal auth_completed(success: bool)

const BASE_URL := SupabaseConfig.URL
const ANON_KEY := SupabaseConfig.ANON_KEY

var _access_token: String = ""
var _user_id: String = ""
var _refresh_token: String = ""

func _get_headers() -> Array:
    var auth := ANON_KEY if _access_token == "" else _access_token
    return [
        "apikey: " + ANON_KEY,
        "Authorization: Bearer " + auth,
        "Content-Type: application/json",
        "Prefer: return=representation"
    ]

func sign_in_anonymous() -> void:
	var saved: Dictionary = _load_token()
	if not saved.is_empty():
		_access_token = saved.get("access_token", "")
		_user_id = saved.get("user_id", "")
		_refresh_token = saved.get("refresh_token", "")
		if _refresh_token != "":
			_do_refresh()
			return
	_do_signup()

func _do_signup() -> void:
    var url := BASE_URL + "/auth/v1/signup"
    var http := HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_auth_completed.bind(http))
    var body := JSON.stringify({"data": {}})
    var headers := [
        "apikey: " + ANON_KEY,
        "Content-Type: application/json"
    ]
    http.request(url, headers, HTTPClient.METHOD_POST, body)

func _do_refresh() -> void:
    var url := BASE_URL + "/auth/v1/token?grant_type=refresh_token"
    var http := HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_auth_completed.bind(http))
    var body := JSON.stringify({"refresh_token": _refresh_token})
    var headers := [
        "apikey: " + ANON_KEY,
        "Content-Type: application/json"
    ]
    http.request(url, headers, HTTPClient.METHOD_POST, body)

func refresh_token() -> void:
	if _refresh_token == "":
		return
	_do_refresh()
	await auth_completed

func _on_auth_completed(_result: int, response_code: int,
                         _headers: PackedStringArray,
                         body: PackedByteArray,
                         http_node: HTTPRequest) -> void:
    if response_code == 200:
        var json: Variant = JSON.parse_string(
            body.get_string_from_utf8())
        if json and "access_token" in json:
            _access_token = json.access_token
            _user_id = json.user.id
            if "refresh_token" in json:
                _refresh_token = json.refresh_token
            _save_token()
            if "expires_in" in json:
                var expires_in: int = int(json.expires_in)
                get_tree().create_timer(max(expires_in - 60, 60)).timeout.connect(_do_refresh)
            print("Auth exitosa: ", _user_id)
            http_node.queue_free()
            emit_signal("auth_completed", true)
            return
    print("Auth error: ", response_code)
    if GameManager.debug_gps:
        GameManager.log_debug("auth code: " + str(response_code))
        GameManager.log_debug("body: " + body.get_string_from_utf8().left(80))
    _clear_token()
    http_node.queue_free()
    # Si el refresh falló, intentar sign_in de nuevo
    if response_code >= 400 and _refresh_token != "":
        _refresh_token = ""
        await sign_in_anonymous()
    else:
        emit_signal("auth_completed", false)

func _save_token() -> void:
    var config := ConfigFile.new()
    config.set_value("auth", "access_token", _access_token)
    config.set_value("auth", "user_id", _user_id)
    config.set_value("auth", "refresh_token", _refresh_token)
    config.save("user://auth.cfg")

func _load_token() -> Dictionary:
    var config := ConfigFile.new()
    if config.load("user://auth.cfg") == OK:
        return {
            "access_token": config.get_value(
                "auth", "access_token", ""),
            "user_id": config.get_value(
                "auth", "user_id", ""),
            "refresh_token": config.get_value(
                "auth", "refresh_token", "")
        }
    return {}

func has_saved_token() -> bool:
    var config := ConfigFile.new()
    var err := config.load("user://auth.cfg")
    return err == OK and config.has_section_key("auth", "refresh_token")

func _clear_token() -> void:
    var config := ConfigFile.new()
    config.save("user://auth.cfg")
    _access_token = ""
    _user_id = ""
    _refresh_token = ""

func select(table: String, filters: String = "") -> HTTPRequest:
	var url := BASE_URL + "/rest/v1/" + table
	if filters != "":
		url += "?" + filters
	var http := HTTPRequest.new()
	add_child(http)
	http.request(url, _get_headers(), HTTPClient.METHOD_GET)
	return http

func insert(table: String, data: Dictionary) -> HTTPRequest:
	var url := BASE_URL + "/rest/v1/" + table
	var http := HTTPRequest.new()
	add_child(http)
	var body := JSON.stringify(data)
	http.request(url, _get_headers(), HTTPClient.METHOD_POST, body)
    return http

func upsert(table: String, data: Dictionary) -> HTTPRequest:
	var url := BASE_URL + "/rest/v1/" + table
	var headers := _get_headers()
	headers.append("Prefer: resolution=merge-duplicates")
	var http := HTTPRequest.new()
	add_child(http)
	var body := JSON.stringify(data)
	http.request(url, headers, HTTPClient.METHOD_POST, body)
	return http

func update(table: String, payload: Dictionary, filter: String) -> HTTPRequest:
	var url: String = BASE_URL + "/rest/v1/" + table + "?" + filter
	var body: String = JSON.stringify(payload)
	var headers: Array = _get_headers()
	headers.append("Prefer: return=minimal")
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	http.request(url, headers, HTTPClient.METHOD_PATCH, body)
	return http

func supabase_rpc(function_name: String, args: Dictionary) -> HTTPRequest:
	var url := BASE_URL + "/rest/v1/rpc/" + function_name
	var http := HTTPRequest.new()
	add_child(http)
	var body := JSON.stringify(args)
	var err: int = http.request(url, _get_headers(), HTTPClient.METHOD_POST, body)
	print("[RPC] ", function_name, " url: ", url, " err: ", err)
	return http
