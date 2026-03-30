extends Node

signal auth_completed(success: bool)

const BASE_URL := SupabaseConfig.URL
const ANON_KEY := SupabaseConfig.ANON_KEY

var _access_token: String = ""
var _user_id: String = ""

func _get_headers() -> Array:
    var auth := ANON_KEY if _access_token == "" else _access_token
    return [
        "apikey: " + ANON_KEY,
        "Authorization: Bearer " + auth,
        "Content-Type: application/json",
        "Prefer: return=representation"
    ]

func sign_in_anonymous() -> void:
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
            print("Auth exitosa: ", _user_id)
            http_node.queue_free()
            emit_signal("auth_completed", true)
            return
    print("Auth error: ", response_code)
    http_node.queue_free()
    emit_signal("auth_completed", false)

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
