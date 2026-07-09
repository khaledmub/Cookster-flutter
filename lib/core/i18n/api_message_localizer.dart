import 'package:get/get.dart';

/// Maps Laravel `messages.*` / raw keys from API responses to app locale strings.
class ApiMessageLocalizer {
  const ApiMessageLocalizer._();

  static const Map<String, String> _serverKeyToLocaleKey = {
    'otp_sent': 'otp_sent',
    'registration_otp_sent': 'signup_otp_sent',
    'signup_otp_sent': 'signup_otp_sent',
    'otp_resent': 'otp_resent_success',
    'otp_send_failed': 'otp_delivery_failed',
    'registration_otp_resent': 'otp_resent_success',
    'otp_resend_failed': 'otp_resend_failed',
    'invalid_otp': 'otp_invalid',
    'otp_invalid': 'otp_invalid',
    'otp_expired': 'otp_invalid',
  };

  static String localize(
    dynamic raw, {
    String fallbackLocaleKey = '',
  }) {
    if (raw == null) {
      return fallbackLocaleKey.isNotEmpty ? fallbackLocaleKey.tr : '';
    }

    var message = raw.toString().trim();
    if (message.isEmpty) {
      return fallbackLocaleKey.isNotEmpty ? fallbackLocaleKey.tr : '';
    }

    if (message.startsWith('messages.')) {
      message = message.substring('messages.'.length);
    } else if (message.startsWith('validation.')) {
      message = message.substring('validation.'.length);
    }

    final mapped = _serverKeyToLocaleKey[message];
    if (mapped != null) {
      final translated = mapped.tr;
      if (translated != mapped) {
        return translated;
      }
    }

    final direct = message.tr;
    if (direct != message) {
      return direct;
    }

    final lastSegment = message.split('.').last;
    final lastMapped = _serverKeyToLocaleKey[lastSegment];
    if (lastMapped != null) {
      final translated = lastMapped.tr;
      if (translated != lastMapped) {
        return translated;
      }
    }

    final lastTranslated = lastSegment.tr;
    if (lastTranslated != lastSegment) {
      return lastTranslated;
    }

    return fallbackLocaleKey.isNotEmpty ? fallbackLocaleKey.tr : message;
  }
}
