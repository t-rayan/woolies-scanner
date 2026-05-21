import 'package:flutter_test/flutter_test.dart';
import 'package:woolies_scanner/core/services/supabase_service.dart';

void main() {
  group('SupabaseService.normalizeDate', () {
    test('normalizes DD/MM/YY to DD/MM/YYYY', () {
      expect(SupabaseService.normalizeDate('10/04/25'), '10/04/2025');
    });

    test('normalizes DD-MM-YY to DD/MM/YYYY', () {
      expect(SupabaseService.normalizeDate('10-04-25'), '10/04/2025');
    });

    test('normalizes DD/MM/YYYY stays as is', () {
      expect(SupabaseService.normalizeDate('10/04/2025'), '10/04/2025');
    });

    test('returns today for null input', () {
      final result = SupabaseService.normalizeDate(null);
      // Should be today's date in DD/MM/YYYY format
      expect(result, isNot(''));
      expect(result.split('/').length, 3);
      expect(result.length, 10);
    });

    test('returns today for empty string', () {
      final result = SupabaseService.normalizeDate('');
      expect(result.split('/').length, 3);
    });

    test('returns today for "No Date"', () {
      final result = SupabaseService.normalizeDate('No Date');
      expect(result.split('/').length, 3);
    });

    test('handles single-digit day and month', () {
      expect(SupabaseService.normalizeDate('5/4/25'), '05/04/2025');
    });

    test('handles year 99 as 2099', () {
      expect(SupabaseService.normalizeDate('10/04/99'), '10/04/2099');
    });
  });

  group('SupabaseService.categorizeSheet', () {
    test('OGE aisle returns OGE', () {
      expect(SupabaseService.categorizeSheet(null, 'OGE001'), 'OGE');
      expect(SupabaseService.categorizeSheet(null, 'OGE012'), 'OGE');
    });

    test('FGE prefixed aisle returns FGE', () {
      expect(SupabaseService.categorizeSheet(null, 'FGE001'), 'FGE');
      expect(SupabaseService.categorizeSheet(null, 'FGE015'), 'FGE');
    });

    test('ENT prefixed aisle returns FGE', () {
      expect(SupabaseService.categorizeSheet(null, 'ENT001'), 'FGE');
      expect(SupabaseService.categorizeSheet(null, 'ENT - Entrance'), 'FGE');
    });

    test('POS aisle returns FGE', () {
      expect(SupabaseService.categorizeSheet(null, 'POS'), 'FGE');
    });

    test('BIN aisle returns FGE', () {
      expect(SupabaseService.categorizeSheet(null, 'BIN'), 'FGE');
      expect(SupabaseService.categorizeSheet(null, 'FRONT OF STORE'), 'FGE');
    });

    test('FLEXI aisle returns FGE', () {
      expect(SupabaseService.categorizeSheet(null, 'FLEXI STAND'), 'FGE');
    });

    test('sheet name is used when aisle is null', () {
      expect(SupabaseService.categorizeSheet('OGE', null), 'OGE');
      expect(SupabaseService.categorizeSheet('FGE', null), 'FGE');
    });

    test('defaults to OGE for unknown aisle', () {
      expect(SupabaseService.categorizeSheet(null, 'GENERAL'), 'OGE');
      expect(SupabaseService.categorizeSheet('', ''), 'OGE');
    });

    test('OGE in sheet name with null aisle returns OGE', () {
      expect(SupabaseService.categorizeSheet('OGE', null), 'OGE');
    });
  });
}
