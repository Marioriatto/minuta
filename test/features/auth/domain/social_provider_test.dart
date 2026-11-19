import 'package:colchon_minuta/features/auth/domain/social_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple solo se ofrece en iOS', () {
    expect(socialProvidersFor(isIOS: false), [SocialProvider.google]);
    expect(
      socialProvidersFor(isIOS: true),
      [SocialProvider.google, SocialProvider.apple],
    );
  });
}
