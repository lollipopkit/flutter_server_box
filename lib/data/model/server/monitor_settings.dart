/// A `monitor` agent's own configuration, as `GET/PUT /api/v1/settings`
/// exposes it.
///
/// The agent writes these to its `config.toml`, so this is the app editing the
/// *server's* settings rather than its own record of that server (which is
/// `Spi`). Deliberately a whitelist on the agent's side: `jwt_secret` and
/// `database_url` are not in it, and neither are the `remote_access` grants —
/// a panel password must not be able to widen what an agent exposes. The
/// notification channels have their own endpoint; see `monitor_push.dart`.
library;

/// One alerting rule. The four fields are free-form strings on the wire
/// because the agent parses them itself and answers with a message naming the
/// one it could not read — repeating that parser here would only mean two
/// opinions about what `>=80%` means.
class MonitorRule {
  final String name;
  final String monitorType;
  final String threshold;
  final String matcher;

  const MonitorRule({
    required this.name,
    required this.monitorType,
    required this.threshold,
    required this.matcher,
  });

  factory MonitorRule.fromJson(Map<String, dynamic> json) => MonitorRule(
    name: json['name'] as String? ?? '',
    monitorType: json['monitor_type'] as String? ?? '',
    threshold: json['threshold'] as String? ?? '',
    matcher: json['matcher'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'monitor_type': monitorType,
    'threshold': threshold,
    'matcher': matcher,
  };

  MonitorRule copyWith({
    String? name,
    String? monitorType,
    String? threshold,
    String? matcher,
  }) => MonitorRule(
    name: name ?? this.name,
    monitorType: monitorType ?? this.monitorType,
    threshold: threshold ?? this.threshold,
    matcher: matcher ?? this.matcher,
  );
}

/// How long the agent keeps what it has collected.
///
/// Absent on the wire means *no cleanup runs at all* and the database grows
/// without limit — not "the defaults apply". That is why the agent also sends
/// [MonitorSettings.dataRetentionDefaults]: an editor offering to switch this
/// on has to have something to put in it, and copying the agent's defaults
/// into the app would mean two places to change them.
class MonitorDataRetention {
  final int metricsDays;
  final int alertsDays;
  final int cleanupIntervalHours;

  /// Hard cap on the live database, in MiB. 0 disables the cap.
  final int maxDbSizeMb;

  const MonitorDataRetention({
    required this.metricsDays,
    required this.alertsDays,
    required this.cleanupIntervalHours,
    required this.maxDbSizeMb,
  });

  factory MonitorDataRetention.fromJson(Map<String, dynamic> json) {
    return MonitorDataRetention(
      metricsDays: (json['metrics_days'] as num?)?.toInt() ?? 30,
      alertsDays: (json['alerts_days'] as num?)?.toInt() ?? 90,
      cleanupIntervalHours:
          (json['cleanup_interval_hours'] as num?)?.toInt() ?? 24,
      maxDbSizeMb: (json['max_db_size_mb'] as num?)?.toInt() ?? 256,
    );
  }

  Map<String, dynamic> toJson() => {
    'metrics_days': metricsDays,
    'alerts_days': alertsDays,
    'cleanup_interval_hours': cleanupIntervalHours,
    'max_db_size_mb': maxDbSizeMb,
  };
}

class MonitorSettings {
  final int intervalSeconds;

  /// Null = the agent's own default, a much slower cadence than
  /// [intervalSeconds] rather than the same one.
  final int? extendedIntervalSecs;

  final bool idlePauseEnabled;

  /// Null = `interval_seconds * 4`.
  final int? idlePauseThresholdSecs;

  final List<MonitorRule> rules;

  /// Null = nothing is ever deleted. See [MonitorDataRetention].
  final MonitorDataRetention? dataRetention;

  final List<String> corsAllowedOrigins;

  /// Which of the fields above take effect on save. Everything else waits for
  /// the agent to restart, and the editor says so per field rather than
  /// guessing — the set has changed before.
  final List<String> liveFields;

  /// What [dataRetention] should become when it is switched on. GET-only.
  final MonitorDataRetention dataRetentionDefaults;

  const MonitorSettings({
    required this.intervalSeconds,
    this.extendedIntervalSecs,
    this.idlePauseEnabled = true,
    this.idlePauseThresholdSecs,
    this.rules = const [],
    this.dataRetention,
    this.corsAllowedOrigins = const [],
    this.liveFields = const [],
    this.dataRetentionDefaults = const MonitorDataRetention(
      metricsDays: 30,
      alertsDays: 90,
      cleanupIntervalHours: 24,
      maxDbSizeMb: 256,
    ),
  });

  factory MonitorSettings.fromJson(Map<String, dynamic> json) {
    final retention = json['data_retention'];
    final defaults = json['data_retention_defaults'];
    return MonitorSettings(
      intervalSeconds: (json['interval_seconds'] as num?)?.toInt() ?? 7,
      extendedIntervalSecs: (json['extended_interval_secs'] as num?)?.toInt(),
      idlePauseEnabled: json['idle_pause_enabled'] != false,
      idlePauseThresholdSecs: (json['idle_pause_threshold_secs'] as num?)
          ?.toInt(),
      rules: switch (json['rules']) {
        final List list => [
          for (final rule in list)
            if (rule is Map<String, dynamic>) MonitorRule.fromJson(rule),
        ],
        _ => const [],
      },
      dataRetention: retention is Map<String, dynamic>
          ? MonitorDataRetention.fromJson(retention)
          : null,
      corsAllowedOrigins: switch (json['cors_allowed_origins']) {
        final List list => list.whereType<String>().toList(),
        _ => const [],
      },
      liveFields: switch (json['live_fields']) {
        final List list => list.whereType<String>().toList(),
        _ => const [],
      },
      // An agent older than this field answers without it. Its own defaults
      // are what this falls back to, which is the same answer it would give.
      dataRetentionDefaults: defaults is Map<String, dynamic>
          ? MonitorDataRetention.fromJson(defaults)
          : const MonitorDataRetention(
              metricsDays: 30,
              alertsDays: 90,
              cleanupIntervalHours: 24,
              maxDbSizeMb: 256,
            ),
    );
  }

  /// Exactly the agent's `SettingsPayload`, and nothing else: a PUT replaces
  /// every field it names, so sending one the agent does not expect is a 400
  /// and *omitting* one it does expect clears it.
  Map<String, dynamic> toPayload() => {
    'interval_seconds': intervalSeconds,
    'extended_interval_secs': extendedIntervalSecs,
    'idle_pause_enabled': idlePauseEnabled,
    'idle_pause_threshold_secs': idlePauseThresholdSecs,
    'rules': [for (final rule in rules) rule.toJson()],
    'data_retention': dataRetention?.toJson(),
    'cors_allowed_origins': corsAllowedOrigins,
  };

  bool isLive(String field) => liveFields.contains(field);

  MonitorSettings copyWith({
    int? intervalSeconds,
    int? Function()? extendedIntervalSecs,
    bool? idlePauseEnabled,
    int? Function()? idlePauseThresholdSecs,
    List<MonitorRule>? rules,
    MonitorDataRetention? Function()? dataRetention,
    List<String>? corsAllowedOrigins,
  }) => MonitorSettings(
    intervalSeconds: intervalSeconds ?? this.intervalSeconds,
    extendedIntervalSecs: extendedIntervalSecs == null
        ? this.extendedIntervalSecs
        : extendedIntervalSecs(),
    idlePauseEnabled: idlePauseEnabled ?? this.idlePauseEnabled,
    idlePauseThresholdSecs: idlePauseThresholdSecs == null
        ? this.idlePauseThresholdSecs
        : idlePauseThresholdSecs(),
    rules: rules ?? this.rules,
    dataRetention: dataRetention == null ? this.dataRetention : dataRetention(),
    corsAllowedOrigins: corsAllowedOrigins ?? this.corsAllowedOrigins,
    liveFields: liveFields,
    dataRetentionDefaults: dataRetentionDefaults,
  );
}
