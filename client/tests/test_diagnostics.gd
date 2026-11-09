extends Node
## Exercise buffered logging, report ZIP generation, rotation and debug flag.

var failures: int = 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, explanation: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_DIAGNOSTICS_TEST_FAIL: " + explanation)

func _run() -> void:
    var logger = RTSDiagnostics
    _check(logger.enabled, "CI must run a debug Godot session")
    if not logger.enabled:
        get_tree().quit(1)
        return
    _check(bool(ProjectSettings.get_setting_with_override("debug/file_logging/enable_file_logging")),
        "Godot engine file logging should be enabled for debug")
    _check(FileAccess.file_exists("user://logs/godot.log"), "Godot engine output log missing")
    _check(not bool(ProjectSettings.get_setting_with_override_and_custom_features(
        "debug/file_logging/enable_file_logging", PackedStringArray(["release"]))),
        "Godot engine logging must be disabled in release feature mode")
    logger.event("test", "diagnostics_smoke", {"unit": "Amina", "answer": 42})
    logger._flush()
    _check(FileAccess.file_exists("user://rts-diagnostics/events-0.jsonl"), "JSONL file not created")
    var content := FileAccess.get_file_as_string("user://rts-diagnostics/events-0.jsonl")
    _check(content.contains("diagnostics_smoke"), "event not persisted to disk")
    _check(content.contains("Amina"), "event payload lost")
    var report: String = logger.make_report()
    _check(not report.is_empty() and FileAccess.file_exists(report), "report ZIP not written")
    var zip := ZIPReader.new()
    if zip.open(report) == OK:
        var files := Array(zip.get_files())
        _check(files.has("manifest.json"), "ZIP lacks manifest")
        _check(files.has("game/events-0.jsonl"), "ZIP lacks game events")
        var metadata: String = zip.read_file("manifest.json").get_string_from_utf8()
        _check(metadata.contains("NEKO: DEAD SIGNAL"), "ZIP contains wrong project")
        zip.close()
    else:
        _check(false, "ZIP cannot be opened")
    var preview: String = logger.report_preview()
    _check(preview.contains("diagnostics_smoke"), "clipboard preview lacks test event")
    _check(preview.length() < 24000, "preview clipboard exceeded fixed cap")
    for i in range(90):
        logger.event("test", "long_report", {"payload": "x".repeat(800)})
    preview = logger.report_preview()
    _check(preview.begins_with("NEKO DEAD SIGNAL DEBUG  |  version=") and preview.contains("session=")
        and preview.length() <= 20000 and preview.contains("long_report"), "long clipboard report lost build/session header")
    logger.event("test", "focus_flush")
    logger.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    _check(FileAccess.get_file_as_string(logger.EVENT_FILE).contains("focus_flush"), "focus loss left queued events unwritten")
    logger.event("test", "pause_flush")
    logger.notification(NOTIFICATION_APPLICATION_PAUSED)
    _check(FileAccess.get_file_as_string(logger.EVENT_FILE).contains("pause_flush"), "Android pause left queued events unwritten")
    if failures == 0:
        print("RTS_DIAGNOSTICS_TEST_PASS")
    get_tree().quit(0 if failures == 0 else 1)
