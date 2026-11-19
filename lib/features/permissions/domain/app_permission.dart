/// Permisos que el SRS (§2.5) exige para operar: notificaciones en segundo
/// plano y micrófono.
enum AppPermission { notifications, microphone }

enum AppPermissionStatus { granted, denied, permanentlyDenied }
