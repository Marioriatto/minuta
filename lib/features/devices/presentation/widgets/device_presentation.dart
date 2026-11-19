import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/device.dart';

extension DeviceKindL10n on AppLocalizations {
  String deviceKindLabel(DeviceKind kind) => switch (kind) {
        DeviceKind.mattress => deviceKindMattress,
        DeviceKind.cradle => deviceKindCradle,
        DeviceKind.lights => deviceKindLights,
        DeviceKind.feeder => deviceKindFeeder,
        DeviceKind.toy => deviceKindToy,
        DeviceKind.room => deviceKindRoom,
        DeviceKind.unknown => deviceKindUnknown,
      };
}

IconData deviceKindIcon(DeviceKind kind) => switch (kind) {
      DeviceKind.mattress => Icons.bed_rounded,
      DeviceKind.cradle => Icons.crib_rounded,
      DeviceKind.lights => Icons.lightbulb_outline_rounded,
      DeviceKind.feeder => Icons.restaurant_outlined,
      DeviceKind.toy => Icons.toys_outlined,
      DeviceKind.room => Icons.meeting_room_outlined,
      DeviceKind.unknown => Icons.extension_outlined,
    };

/// Un decimal con coma (24,1). Nulo se muestra como guion.
String formatDecimal(double? value) =>
    value == null ? '—' : value.toStringAsFixed(1).replaceAll('.', ',');

/// Texto editable de un umbral: sin decimales si es entero.
String thresholdText(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString().replaceAll('.', ',');
}

/// Punto verde/gris con el estado de conexión del módulo.
class OnlineDot extends StatelessWidget {
  const OnlineDot({required this.online, super.key});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? const Color(0xFF2E8B6A) : scheme.outline,
      ),
    );
  }
}
