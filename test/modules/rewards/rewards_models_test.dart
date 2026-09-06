import 'package:cookster/modules/rewards/rewards_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QR payload', () {
    test('prefixes hmac and leaves full payload unchanged', () {
      expect(
        normalizeRewardQrPayload('abc123'),
        'cookster_redeem:abc123',
      );
      expect(
        normalizeRewardQrPayload('cookster_redeem:abc123'),
        'cookster_redeem:abc123',
      );
      expect(
        rewardScanToken('cookster_redeem:hmac'),
        'cookster_redeem:hmac',
      );
    });
  });

  group('RewardMyCode', () {
    test('parses root and nested data', () {
      final fromRoot = RewardMyCode.fromJson({
        'status': true,
        'payload': 'cookster_redeem:tok',
        'expires_in': 60,
        'eligible': true,
      });
      expect(fromRoot.payload, 'cookster_redeem:tok');
      expect(fromRoot.expiresIn, 60);

      final fromData = RewardMyCode.fromJson({
        'status': true,
        'data': {'payload': 'tok', 'expires_in': 45, 'eligible': false},
      });
      expect(fromData.payload, 'cookster_redeem:tok');
      expect(fromData.expiresIn, 45);
      expect(fromData.eligible, isFalse);
    });
  });

  group('RewardDeal', () {
    test('parses quantity aliases', () {
      final deal = RewardDeal.fromJson({
        'deal': {
          'id': '1',
          'title': 'Coffee',
          'quantity_total': 100,
          'quantity_remaining': 99,
          'status': 'active',
        },
      });
      expect(deal.title, 'Coffee');
      expect(deal.quantityTotal, 100);
      expect(deal.quantityRemaining, 99);
      expect(deal.isActive, isTrue);
    });
  });

  group('error_code', () {
    test('maps known codes and 429', () {
      expect(
        parseRewardErrorCode({'error_code': 'already_redeemed'}),
        'already_redeemed',
      );
      expect(
        parseRewardErrorCode({'status': true, 'error_code': 'success'}),
        'success',
      );
      expect(parseRewardErrorCode({}, statusCode: 429), 'rate_limited');
      expect(rewardErrorLocaleKey('deal_exhausted'), 'reward_error_deal_exhausted');
    });

    test('scan result treats status false as failure', () {
      final result = RewardScanResult.fromJson({
        'status': false,
        'error_code': 'cannot_redeem_own_qr',
        'message': 'Own QR',
      }, statusCode: 422);
      expect(result.success, isFalse);
      expect(result.errorCode, 'cannot_redeem_own_qr');
    });
  });
}
