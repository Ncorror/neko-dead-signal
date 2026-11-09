extends Node
## DEBUG-only, bounded RTS telemetry. No per-frame disk writes. No network telemetry.
## Release exports keep this autoload but skip file allocation and event serialization.

const LOG_DIR := "user://rts-diagnostics"
const REPORT_DIR := LOG_DIR + "/reports"
const EVENT_FILE := LOG_DIR + "/events-0.jsonl"
const MAX_EVENT_BYTES := 393216
const MAX_QUEUE := 32
const FLUSH_INTERVAL_SEC := 2.0
const RETAINED_FILES := 3
const ENGINE_LOG_DIR := "user://logs"
const MAX_ENGINE_LOG_BYTES := 2097152
const MAX_MEM_LINES := 90

var enabled: bool = false
var _stream: FileAccess
var _current_bytes: int = 0
var _queue: Array[String] = []
var _recent: Array[String] = []
var _flush_age: float = 0.0
var _session: String = ""

func _ready() -> void:
    enabled = OS.has_feature("debug")
    if not enabled:
        set_process(false)
        return
    var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
    if err != OK:
        enabled = false
        push_warning("RTS_DIAG_INIT_FAILED code=" + str(err))
        return
    _session = str(int(Time.get_unix_time_from_system()))
    _rotate_events()
    _stream = FileAccess.open(EVENT_FILE, FileAccess.WRITE)
    if _stream == null:
        enabled = false
        push_warning("RTS_DIAG_OPEN_FAILED code=" + str(FileAccess.get_open_error()))
        return
    event("app", "session_start", {
        "session": _session,
        "build": "debug",
        "version": ProjectSettings.get_setting("application/config/version", "dev"),
        "platform": OS.get_name(),
        "renderer": RenderingServer.get_current_rendering_method(),
        "viewport": str(get_viewport().get_visible_rect().size)
    })
    _flush()

func _process(delta: float) -> void:
    if not enabled:
        return
    _flush_age += delta
    if _flush_age >= FLUSH_INTERVAL_SEC:
        _flush()

func event(category: String, name: String, data: Dictionary = {}) -> void:
    if not enabled:
        return
    # Never record tokens, account ids, device ids, passwords, or chat contents.
    var item := {
        "ts": Time.get_datetime_string_from_system(true),
        "ms": Time.get_ticks_msec(),
        "session": _session,
        "category": category,
        "event": name,
        "data": data
    }
    var line: String = JSON.stringify(item)
    _queue.append(line)
    _recent.append(line)
    if _recent.size() > MAX_MEM_LINES:
        _recent.pop_front()
    if _queue.size() >= MAX_QUEUE:
        _flush()

func _rotate_events() -> void:
    for i in range(RETAINED_FILES - 1, 0, -1):
        var prior: String = LOG_DIR + "/events-" + str(i - 1) + ".jsonl"
        var next: String = LOG_DIR + "/events-" + str(i) + ".jsonl"
        if FileAccess.file_exists(next):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(next))
        if FileAccess.file_exists(prior):
            DirAccess.rename_absolute(ProjectSettings.globalize_path(prior), ProjectSettings.globalize_path(next))

func _flush() -> void:
    if not enabled or _stream == null or _queue.is_empty():
        _flush_age = 0.0
        return
    for line in _queue:
        var written: int = line.to_utf8_buffer().size() + 1
        if _current_bytes + written > MAX_EVENT_BYTES:
            _stream.flush()
            _stream.close()
            _rotate_events()
            _stream = FileAccess.open(EVENT_FILE, FileAccess.WRITE)
            _current_bytes = 0
            if _stream == null:
                enabled = false
                _queue.clear()
                return
        _stream.store_line(line)
        _current_bytes += written
    _queue.clear()
    _stream.flush()
    _flush_age = 0.0

func _exit_tree() -> void:
    if enabled:
        _flush()
    if _stream != null:
        _stream.close()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        _flush()

func report_preview() -> String:
    if not enabled:
        return "Диагностика отключена в релизной сборке."
    _flush()
    var header := "NEKO DEAD SIGNAL DEBUG  |  version=" + str(ProjectSettings.get_setting("application/config/version", "dev")) + "  |  session=" + _session + "\n"
    header += "platform=" + OS.get_name() + "  fps=" + str(Engine.get_frames_per_second()) + "\n"
    header += "user_dir=" + OS.get_user_data_dir() + "\n\n"
    # Limit copied clipboard content even after long test sessions.
    var body := "\n".join(_recent) + "\n"
    var budget := maxi(0, 20000 - header.length())
    return header + body.substr(maxi(0, body.length() - budget))

func make_report() -> String:
    if not enabled:
        return ""
    _flush()
    var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIR))
    if err != OK:
        return ""
    # Bounded archive retention: three report slots; no unbounded ZIP accumulation.
    for i in range(RETAINED_FILES - 1, 0, -1):
        var previous := REPORT_DIR + "/report-" + str(i - 1) + ".zip"
        var replacement := REPORT_DIR + "/report-" + str(i) + ".zip"
        if FileAccess.file_exists(replacement):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(replacement))
        if FileAccess.file_exists(previous):
            DirAccess.rename_absolute(ProjectSettings.globalize_path(previous), ProjectSettings.globalize_path(replacement))
    var path := REPORT_DIR + "/report-0.zip"
    var zip := ZIPPacker.new()
    zip.compression_level = 1
    if zip.open(path) != OK:
        return ""
    var manifest := {
        "project": "NEKO: DEAD SIGNAL",
        "version": ProjectSettings.get_setting("application/config/version", "dev"),
        "session": _session,
        "created_utc": Time.get_datetime_string_from_system(true),
        "platform": OS.get_name(),
        "debug_build": enabled,
        "notes": "Local diagnostic bundle: not uploaded automatically. Avoid sharing personal information."
    }
    _pack_bytes(zip, "manifest.json", JSON.stringify(manifest, "  ").to_utf8_buffer())
    for i in range(RETAINED_FILES):
        var p := LOG_DIR + "/events-" + str(i) + ".jsonl"
        if FileAccess.file_exists(p):
            _pack_file(zip, p, "game/" + p.get_file(), MAX_EVENT_BYTES + 1024)
    # Engine errors, GDScript warnings, and print output: if engine file logging is enabled.
    var engine_logs := DirAccess.open(ENGINE_LOG_DIR)
    if engine_logs != null:
        var names := Array(engine_logs.get_files())
        names.sort()
        var count := 0
        for name in names:
            if count >= 4:
                break
            var log_name: String = str(name)
            if not log_name.begins_with("godot") or not log_name.ends_with(".log"):
                continue
            var source: String = ENGINE_LOG_DIR + "/" + log_name
            _pack_file(zip, source, "godot/" + log_name, MAX_ENGINE_LOG_BYTES)
            count += 1
    zip.close()
    event("diagnostics", "report_created", {"path": "report-0.zip"})
    _flush()
    return ProjectSettings.globalize_path(path)

func _pack_file(zip: ZIPPacker, source: String, target: String, limit: int) -> void:
    var file := FileAccess.open(source, FileAccess.READ)
    if file == null:
        return
    var size: int = file.get_length()
    if size > limit:
        file.seek(size - limit)
    var bytes := file.get_buffer(mini(size, limit))
    file.close()
    _pack_bytes(zip, target, bytes)

func _pack_bytes(zip: ZIPPacker, target: String, bytes: PackedByteArray) -> void:
    if zip.start_file(target) != OK:
        return
    zip.write_file(bytes)
    zip.close_file()
