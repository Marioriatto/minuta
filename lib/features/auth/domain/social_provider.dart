enum SocialProvider { google, apple }

/// Apple solo se ofrece en iOS: la tienda lo exige allí si hay login social.
List<SocialProvider> socialProvidersFor({required bool isIOS}) => [
      SocialProvider.google,
      if (isIOS) SocialProvider.apple,
    ];
