import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/audit_entry.dart';
import '../models/saved_sheet.dart';
import '../models/shift_alert.dart';
import '../models/tool_definition.dart';

/// Local settings and audit storage required by the legacy controller.
abstract interface class AppSettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
  Future<List<AuditEntry>> loadAudit();
  Future<void> appendAudit(AuditEntry entry);
  Future<Set<String>> loadPinnedToolIds();
  Future<void> savePinnedToolIds(Iterable<String> ids);
  Future<List<SavedSheet>> loadSavedSheets();
  Future<void> saveSavedSheets(Iterable<SavedSheet> sheets);
  Future<Map<String, ShiftAlertDecision>> loadAlertDecisions();
  Future<void> saveAlertDecision(String alertId, ShiftAlertDecision decision);
}

class SettingsService implements AppSettingsStore {
  static const _nameKey = 'target_name';
  static const _archiveKey = 'archive_original';
  static const _autoRefreshKey = 'auto_refresh';
  static const _autoSyncKey = 'auto_sync';
  static const _refreshSecondsKey = 'refresh_seconds';
  static const _googleWebClientIdKey = 'google_web_client_id';
  static const _orgKey='setup_organization_name', _officerKey='setup_officer_name', _shiftNameKey='setup_shift_name', _shiftColorKey='setup_shift_color', _shiftStartKey='setup_shift_start', _shiftEndKey='setup_shift_end', _receiverKey='setup_shift_receiver', _exchangeKey='setup_shift_exchange_note', _cancelKey='setup_shift_cancellation_note', _setupKey='setup_complete';
  static const _auditKey = 'audit_log';
  static const _pinnedToolIdsKey = 'pinned_tool_ids';
  static const _savedSheetsKey = 'saved_sheets';
  static const _alertDecisionsKey = 'shift_alert_decisions';

  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('passkey_sha256');
    // Older builds stored one global source URL. Remove it so switching Google
    // accounts can never expose or reuse another account's original Sheet.
    await prefs.remove('source_url');
    await prefs.remove('target_name');
    await prefs.remove('target_year');
    await prefs.remove('target_month');
    await prefs.remove('calendar_defaults_version');
    final defaults = AppSettings.defaults();
    return AppSettings(
      targetName: defaults.targetName,
      year: null,
      month: null,
      periods: const [],
      archiveOriginal: prefs.getBool(_archiveKey) ?? defaults.archiveOriginal,
      autoRefresh: prefs.getBool(_autoRefreshKey) ?? defaults.autoRefresh,
      autoSync: prefs.getBool(_autoSyncKey) ?? defaults.autoSync,
      refreshSeconds:
          (prefs.getInt(_refreshSecondsKey) ?? defaults.refreshSeconds).clamp(
            1,
            60,
          ),
      googleWebClientId: prefs.getString(_googleWebClientIdKey) ?? defaults.googleWebClientId,
      organizationName: prefs.getString(_orgKey) ?? '', officerName: prefs.getString(_officerKey) ?? '',
      defaultShiftName: prefs.getString(_shiftNameKey) ?? '', defaultShiftColor: prefs.getString(_shiftColorKey) ?? '#616161',
      defaultShiftStart: prefs.getString(_shiftStartKey) ?? '08:00', defaultShiftEnd: prefs.getString(_shiftEndKey) ?? '16:00',
      defaultShiftReceiver: prefs.getString(_receiverKey) ?? '', shiftExchangeNote: prefs.getString(_exchangeKey) ?? '',
      shiftCancellationNote: prefs.getString(_cancelKey) ?? '', setupComplete: prefs.getBool(_setupKey) ?? false,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_nameKey),
      prefs.remove('target_year'),
      prefs.remove('target_month'),
      prefs.setBool(_archiveKey, settings.archiveOriginal),
      prefs.setBool(_autoRefreshKey, settings.autoRefresh),
      prefs.setBool(_autoSyncKey, settings.autoSync),
      prefs.setInt(_refreshSecondsKey, settings.refreshSeconds.clamp(1, 60)),
      prefs.setString(_googleWebClientIdKey, settings.googleWebClientId),
      prefs.setString(_orgKey, settings.organizationName), prefs.setString(_officerKey, settings.officerName),
      prefs.setString(_shiftNameKey, settings.defaultShiftName), prefs.setString(_shiftColorKey, settings.defaultShiftColor),
      prefs.setString(_shiftStartKey, settings.defaultShiftStart), prefs.setString(_shiftEndKey, settings.defaultShiftEnd),
      prefs.setString(_receiverKey, settings.defaultShiftReceiver), prefs.setString(_exchangeKey, settings.shiftExchangeNote),
      prefs.setString(_cancelKey, settings.shiftCancellationNote), prefs.setBool(_setupKey, settings.setupComplete),
    ]);
  }

  @override
  Future<List<AuditEntry>> loadAudit() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_auditKey) ?? const [];
    return raw
        .map((item) {
          try {
            return AuditEntry.fromJson(
              Map<String, Object?>.from(jsonDecode(item) as Map),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<AuditEntry>()
        .toList();
  }

  @override
  Future<void> appendAudit(AuditEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_auditKey) ?? <String>[];
    entries.insert(0, jsonEncode(entry.toJson()));
    if (entries.length > 200) entries.removeRange(200, entries.length);
    await prefs.setStringList(_auditKey, entries);
  }

  @override
  Future<Set<String>> loadPinnedToolIds() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_pinnedToolIdsKey);
    if (saved == null) return {...defaultPinnedToolIds};
    return saved.where((id) => toolById(id) != null).toSet();
  }

  @override
  Future<void> savePinnedToolIds(Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final validIds = ids.where((id) => toolById(id) != null).toSet().toList()
      ..sort();
    await prefs.setStringList(_pinnedToolIdsKey, validIds);
  }

  @override
  Future<List<SavedSheet>> loadSavedSheets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_savedSheetsKey) ?? const [];
    return raw
        .map((item) {
          try {
            return SavedSheet.fromJson(
              Map<String, Object?>.from(jsonDecode(item) as Map),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedSheet>()
        .toList();
  }

  @override
  Future<void> saveSavedSheets(Iterable<SavedSheet> sheets) async {
    final prefs = await SharedPreferences.getInstance();
    final records = sheets.toList()
      ..sort((left, right) => right.savedAt.compareTo(left.savedAt));
    await prefs.setStringList(
      _savedSheetsKey,
      records.take(100).map((sheet) => jsonEncode(sheet.toJson())).toList(),
    );
  }

  @override
  Future<Map<String, ShiftAlertDecision>> loadAlertDecisions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_alertDecisionsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final values = Map<String, Object?>.from(jsonDecode(raw) as Map);
      return {
        for (final entry in values.entries)
          if (ShiftAlertDecision.values.any(
            (decision) => decision.name == entry.value,
          ))
            entry.key: ShiftAlertDecision.values.byName('${entry.value}'),
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveAlertDecision(
    String alertId,
    ShiftAlertDecision decision,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final decisions = await loadAlertDecisions();
    decisions[alertId] = decision;
    if (decisions.length > 500) decisions.remove(decisions.keys.first);
    await prefs.setString(
      _alertDecisionsKey,
      jsonEncode({
        for (final entry in decisions.entries) entry.key: entry.value.name,
      }),
    );
  }
}
