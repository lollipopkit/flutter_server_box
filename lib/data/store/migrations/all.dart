import 'package:server_box/data/store/migrations/m004_kv_to_tables.dart';
import 'package:server_box/data/store/migrations/m005_monitor_insecure_http.dart';
import 'package:server_box/data/store/migrations/m006_bmc_columns.dart';
import 'package:server_box/data/store/migrations/m007_private_key_comment.dart';
import 'package:server_box/data/store/schema.dart';

/// Every migration, ordered, in the one place that names them.
///
/// `main.dart` and the migration tests both drive the chain, and each used to
/// carry its own copy of the list. A step added to only one of them is a
/// launch that throws `Missing schema migration from vN`, or a test asserting
/// a shape no install is ever in — and which of the two you get depends on
/// which copy was forgotten. There is nothing to forget with one list.
const kSchemaMigrations = <SchemaMigration>[
  KvToTablesMigration(),
  MonitorInsecureHttpMigration(),
  BmcColumnsMigration(),
  PrivateKeyCommentMigration(),
];
