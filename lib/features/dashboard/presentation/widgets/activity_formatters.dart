import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/dashboard_models.dart';

/// Texto de un evento; si el tipo es desconocido usa la descripción guardada.
String activityLabel(AppLocalizations l10n, ActivityEvent event) =>
    switch (event.type) {
      'presence_detected' => l10n.eventPresenceDetected,
      'absence_detected' => l10n.eventAbsenceDetected,
      'movement_detected' => l10n.eventMovementDetected,
      'detection_started' => l10n.eventDetectionStarted,
      'detection_ended' => l10n.eventDetectionEnded,
      'temperature_high' => l10n.eventTemperatureHigh,
      'temperature_low' => l10n.eventTemperatureLow,
      'humidity_high' => l10n.eventHumidityHigh,
      'humidity_low' => l10n.eventHumidityLow,
      'lights_changed' => l10n.eventLightsChanged,
      'feeding_started' => l10n.eventFeedingStarted,
      'feeding_completed' => l10n.eventFeedingCompleted,
      'feeding_reminder' => l10n.eventFeedingReminder,
      'toy_motion' => l10n.eventToyMotion,
      'toy_session_started' => l10n.eventToySessionStarted,
      'toy_session_ended' => l10n.eventToySessionEnded,
      'door_opened' => l10n.eventDoorOpened,
      'room_motion' => l10n.eventRoomMotion,
      _ => (event.description?.trim().isNotEmpty ?? false)
          ? event.description!.trim()
          : l10n.eventOther,
    };

IconData activityIcon(ActivityCategory category) => switch (category) {
      ActivityCategory.mattress => Icons.bed_rounded,
      ActivityCategory.environment => Icons.thermostat_rounded,
      ActivityCategory.lights => Icons.lightbulb_outline_rounded,
      ActivityCategory.feeding => Icons.restaurant_outlined,
      ActivityCategory.toy => Icons.toys_outlined,
      ActivityCategory.room => Icons.meeting_room_outlined,
      ActivityCategory.other => Icons.circle_notifications_outlined,
    };
