import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;

import '../domain/calendar_gateway.dart';

class GoogleCalendarGateway implements CalendarGateway {
  GoogleCalendarGateway(this._client);

  final http.Client _client;

  @override
  Future<void> verifyAccess() async {
    final api = calendar.CalendarApi(_client);
    await api.calendars.get('primary');
  }
}
