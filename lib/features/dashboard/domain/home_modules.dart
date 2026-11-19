import '../../devices/domain/device.dart';
import 'dashboard_models.dart';

enum MattressPresence { occupied, empty, unknown }

/// Módulos que resume el inicio. Si hay más de uno del mismo tipo se usa el
/// que habló más recientemente con el servidor.
class HomeModules {
  const HomeModules({this.mattress, this.cradle, this.lights});

  factory HomeModules.from(Iterable<Device> devices) {
    Device? pick(DeviceKind kind) {
      Device? best;
      for (final d in devices) {
        if (d.kind != kind) continue;
        final seen = d.lastSeenAt;
        final bestSeen = best?.lastSeenAt;
        if (best == null ||
            (seen != null && (bestSeen == null || seen.isAfter(bestSeen)))) {
          best = d;
        }
      }
      return best;
    }

    return HomeModules(
      mattress: pick(DeviceKind.mattress),
      cradle: pick(DeviceKind.cradle),
      lights: pick(DeviceKind.lights),
    );
  }

  final Device? mattress;
  final Device? cradle;
  final Device? lights;

  /// Presencia del bebé según el peso actual. Sin conexión no se afirma nada.
  static MattressPresence presenceOf(Device mattress, DateTime now) {
    final weight = mattress.weightKg;
    if (!mattress.isOnline(now) || weight == null) {
      return MattressPresence.unknown;
    }
    return weight >= DashboardSeries.minBabyWeightKg
        ? MattressPresence.occupied
        : MattressPresence.empty;
  }
}
