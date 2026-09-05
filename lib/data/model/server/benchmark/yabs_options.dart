import 'package:freezed_annotation/freezed_annotation.dart';

part 'yabs_options.freezed.dart';
part 'yabs_options.g.dart';

/// Which Geekbench release to run.
///
/// The number is the flag: yabs spells the choice `-4`, `-5`, `-6`, `-7`.
enum GeekbenchVersion {
  @JsonValue('v4')
  v4('4'),
  @JsonValue('v5')
  v5('5'),
  @JsonValue('v6')
  v6('6'),
  @JsonValue('v7')
  v7('7');

  const GeekbenchVersion(this.flagDigit);

  final String flagDigit;

  String get label => 'Geekbench $flagDigit';
}

/// What the user asked a benchmark run to do.
///
/// Every phase yabs can run is a field here and every one of them is reachable
/// from the configuration sheet, because each costs something the person paying
/// for the server is the only one who can weigh: disk writes, egress, or
/// telling a third party about the machine. The defaults below are this app's
/// opinion and nothing more — none of them is enforced.
///
/// Three of them deliberately disagree with yabs' own defaults, each in the
/// direction that spends less of someone else's money or discloses less:
///
/// - [cpu] is off. A Geekbench run **publishes** its result — CPU model, core
///   count, memory, and a public `browser.geekbench.com` URL — and downloads a
///   proprietary binary to do it. That is a disclosure about the user's server
///   to a third party, and it should not happen because someone tapped Run
///   without reading.
/// - [reducedNetwork] is on. The full set is seven locations, each tested in
///   both directions for 15 seconds with eight parallel streams: on a 1 Gbps
///   host that is tens of gigabytes, twice over if the machine has both address
///   families. Three locations still answers "is my network any good".
/// - [ipInfo] is off. The lookup sends the server's public address to
///   `ip-api.com` over **plaintext HTTP**.
///
/// yabs' `-p` — a custom iperf server list — is deliberately not offered. Its
/// `host:port_range:name:location:modes` is a format to get wrong rather than a
/// setting to choose, and the built-in locations are what makes one machine's
/// numbers comparable with another's, which is the whole point of keeping them.
///
/// Stored with each run so a result always says what produced it — a benchmark
/// whose parameters are not recorded cannot be compared with another.
@freezed
abstract class YabsOptions with _$YabsOptions {
  const YabsOptions._();

  const factory YabsOptions({
    /// fio: 4k/64k/512k/1m, mixed read/write, ~30s each.
    ///
    /// Writes a 2 GB test file (512 MB on ARM) into [workDir] and needs that
    /// much free, or yabs skips the phase and says so in the log.
    @Default(true) bool disk,

    /// iperf3 against public servers. See [reducedNetwork] for the cost.
    @Default(true) bool network,

    /// Three iperf locations instead of seven.
    @Default(true) bool reducedNetwork,

    /// Geekbench. Off by default — see the note on this class.
    @Default(false) bool cpu,

    @Default(GeekbenchVersion.v6) GeekbenchVersion geekbenchVersion,

    /// Look the server's public address up with ip-api.com. Off by default —
    /// see the note on this class.
    @Default(false) bool ipInfo,

    /// yabs' `-b`: use the binaries it ships rather than the host's own fio and
    /// iperf3.
    ///
    /// Off, so a host that has the packages uses them and needs no network for
    /// this at all. Turning it on means fetching from raw.githubusercontent.com,
    /// which a good share of hosts cannot reach.
    @Default(false) bool preferPrecompiledBinaries,

    /// Where the run happens, and therefore **which filesystem fio measures**.
    ///
    /// Empty means the login account's home directory. Anyone benchmarking a
    /// second disk needs this; there is no other way to point fio at one.
    @Default('') String workDir,
  }) = _YabsOptions;

  factory YabsOptions.fromJson(Map<String, dynamic> json) =>
      _$YabsOptionsFromJson(json);

  /// Whether this asks for anything at all.
  ///
  /// Everything off still collects the system information header, which is a
  /// legitimate thing to want and takes seconds — so this is not an error, only
  /// something the sheet says out loud before the run starts.
  bool get isSystemInfoOnly => !disk && !network && !cpu;

  /// The yabs flags, in the order its `getopts` loop reads them.
  ///
  /// `-w` is not here: the output path belongs to the runner, which owns the
  /// directory it writes into.
  List<String> get flags {
    return [
      if (preferPrecompiledBinaries) '-b',
      if (!disk) '-f',
      if (!network) '-i',
      // Only meaningful with the network phase on, and yabs reads a stray one
      // harmlessly — but a flag list that says something the run will not do is
      // a flag list nobody can check against the log.
      if (network && reducedNetwork) '-r',
      if (!ipInfo) '-n',
      // Never both: `-g` sets the skip and any digit clears the default, so
      // sending the pair would ask for a version of a phase that is skipped.
      if (!cpu) '-g' else '-${geekbenchVersion.flagDigit}',
    ];
  }
}
