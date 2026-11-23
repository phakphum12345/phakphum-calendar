import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

/// Convenient, non-null access to the generated application localizations.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEn();
}

AppLocalizations localizationsForLocale(Locale? locale) {
  return locale?.languageCode == 'th'
      ? AppLocalizationsTh()
      : AppLocalizationsEn();
}

String? workflowMessageFor(AppLocalizations l10n, String key) => switch (key) {
  'workflowScheduleFailedValidation' => l10n.workflowScheduleFailedValidation,
  'workflowReadyToConfirm' => l10n.workflowReadyToConfirm,
  'workflowWarningsBeforeConfirm' => l10n.workflowWarningsBeforeConfirm,
  'workflowCalendarCheckFailed' => l10n.workflowCalendarCheckFailed,
  'workflowNoValidatedPlan' => l10n.workflowNoValidatedPlan,
  'workflowNoValidationResult' => l10n.workflowNoValidationResult,
  'workflowItemsStillBlocked' => l10n.workflowItemsStillBlocked,
  'workflowSyncPartialSuccess' => l10n.workflowSyncPartialSuccess,
  'workflowSyncSuccessful' => l10n.workflowSyncSuccessful,
  'workflowSyncFailed' => l10n.workflowSyncFailed,
  _ => null,
};
