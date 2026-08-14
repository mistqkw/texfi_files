package app.texfi.texfi_files

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity (не FlutterActivity) — нужно audio_service, чтобы
// плеер жил в общем FlutterEngine и переживал переход в фоновый сервис.
class MainActivity : AudioServiceActivity()
