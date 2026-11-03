class AppSettings {
  const AppSettings({
    this.server = '',
    this.port = '1433',
    this.database = '',
    this.driver = 'ODBC Driver 18 for SQL Server',
    this.username = '',
    this.password = '',
    this.trustedConnection = false,
    this.defaultDateFrom = '',
    this.defaultDeviseCode = '',
    this.defaultPriceTypeCode = '',
    this.defaultPriceCategoryCode = '',
  });

  final String server, port, database, driver, username, password;
  final bool trustedConnection;
  final String defaultDateFrom, defaultDeviseCode;
  final String defaultPriceTypeCode, defaultPriceCategoryCode;

  Map<String, dynamic> toJson() => {
        'server': server, 'port': port, 'database': database, 'driver': driver,
        'username': username, 'password': password,
        'trustedConnection': trustedConnection,
        'defaultDateFrom': defaultDateFrom,
        'defaultDeviseCode': defaultDeviseCode,
        'defaultPriceTypeCode': defaultPriceTypeCode,
        'defaultPriceCategoryCode': defaultPriceCategoryCode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        server: json['server'] as String? ?? '',
        port: json['port'] as String? ?? '1433',
        database: json['database'] as String? ?? '',
        driver: json['driver'] as String? ?? 'ODBC Driver 18 for SQL Server',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        trustedConnection: json['trustedConnection'] as bool? ?? false,
        defaultDateFrom: json['defaultDateFrom'] as String? ?? '',
        defaultDeviseCode: json['defaultDeviseCode'] as String? ?? '',
        defaultPriceTypeCode: json['defaultPriceTypeCode'] as String? ?? '',
        defaultPriceCategoryCode: json['defaultPriceCategoryCode'] as String? ?? '',
      );

  AppSettings copyWith({
    String? server, String? port, String? database, String? driver,
    String? username, String? password, bool? trustedConnection,
    String? defaultDateFrom, String? defaultDeviseCode,
    String? defaultPriceTypeCode, String? defaultPriceCategoryCode,
  }) => AppSettings(
        server: server ?? this.server, port: port ?? this.port,
        database: database ?? this.database, driver: driver ?? this.driver,
        username: username ?? this.username, password: password ?? this.password,
        trustedConnection: trustedConnection ?? this.trustedConnection,
        defaultDateFrom: defaultDateFrom ?? this.defaultDateFrom,
        defaultDeviseCode: defaultDeviseCode ?? this.defaultDeviseCode,
        defaultPriceTypeCode: defaultPriceTypeCode ?? this.defaultPriceTypeCode,
        defaultPriceCategoryCode: defaultPriceCategoryCode ?? this.defaultPriceCategoryCode,
      );
}
