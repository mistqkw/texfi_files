package app.texfi.texfi_files

import com.ryanheise.audioservice.AudioServiceFragmentActivity

// AudioServiceFragmentActivity (наследник FlutterFragmentActivity) — нужно
// сразу двум плагинам:
//  • audio_service — чтобы плеер жил в общем FlutterEngine и переживал
//    переход в фоновый сервис (шторка/экран блокировки);
//  • local_auth — биометрия (отпечаток) на Android показывается только из
//    FragmentActivity; с обычной FlutterActivity вход по отпечатку молча
//    падал с no_fragment_activity.
class MainActivity : AudioServiceFragmentActivity()
