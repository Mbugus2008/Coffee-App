class BcSettings {
  final String odataBaseUrl;
  final String company;
  final String username;
  final String password;
  final String factory;

  const BcSettings({
    required this.odataBaseUrl,
    required this.company,
    required this.username,
    required this.password,
    required this.factory,
  });

  BcSettings copyWith({
    String? odataBaseUrl,
    String? company,
    String? username,
    String? password,
    String? factory,
  }) {
    return BcSettings(
      odataBaseUrl: odataBaseUrl ?? this.odataBaseUrl,
      company: company ?? this.company,
      username: username ?? this.username,
      password: password ?? this.password,
      factory: factory ?? this.factory,
    );
  }

  static const defaults = BcSettings(
    odataBaseUrl: 'http://test.trimline.co.ke:4548/BC240/ODataV4',
    company: 'INUKA',
    username: 'Philip',
    password: 'Password@2030',
    factory: '',
  );
}
