import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:phakphum_calendar/models/shift.dart';
import 'package:phakphum_calendar/services/sheets_service.dart';
import 'package:phakphum_calendar/services/shift_color_service.dart';

void main() {
  test('maps source roster colors to the standard categories', () {
    expect(ShiftColorService.classify(0xFF616161)?.category, ShiftCategory.own);
    expect(
      ShiftColorService.classify(0xFFD50000)?.category,
      ShiftCategory.other,
    );
    expect(
      ShiftColorService.classify(0xFF039BE5)?.category,
      ShiftCategory.clinic,
    );
    expect(
      ShiftColorService.classify(0xFFDBADFF)?.category,
      ShiftCategory.specialClinic,
    );
    expect(
      ShiftColorService.classify(0xFFFBD75B)?.category,
      ShiftCategory.borrowedUnpaid,
    );
    expect(
      ShiftColorService.classify(0xFF7AE7BF)?.category,
      ShiftCategory.borrowedPaid,
    );
    expect(ShiftColorService.classify(0xFFFFFFFF), isNull);

    final lavender = ShiftColorService.classify(0xFFA4BDFC);
    expect(lavender?.sourceName, 'ลาเวนเดอร์');
    expect(lavender?.requiresReview, isTrue);
  });

  test('uses the requested Google Calendar target color IDs', () {
    expect(ShiftCategory.own.googleColorId, '9');
    expect(ShiftCategory.other.googleColorId, '11');
    expect(ShiftCategory.clinic.googleColorId, '5');
    expect(ShiftCategory.specialClinic.googleColorId, '6');
    expect(ShiftCategory.majorSwap.googleColorId, '9');
    expect(ShiftCategory.given.googleColorId, '10');
    expect(ShiftCategory.borrowedUnpaid.googleColorId, '5');
    expect(ShiftCategory.borrowedPaid.googleColorId, '10');
    expect(ShiftCategory.off.googleColorId, '8');
  });

  test('extracts effective background RGB from the original sheet grid', () {
    final sheet = sheets.Sheet(
      properties: sheets.SheetProperties(title: 'ทดสอบ'),
      data: [
        sheets.GridData(
          startRow: 2,
          startColumn: 3,
          rowData: [
            sheets.RowData(
              values: [
                sheets.CellData(
                  effectiveFormat: sheets.CellFormat(
                    backgroundColorStyle: sheets.ColorStyle(
                      rgbColor: sheets.Color(red: 1, green: 0, blue: 0),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final colors = SheetsService.backgroundColorsForSheet(sheet);

    expect(colors[2][3], 0xFFFF0000);
  });
}
