import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteAppConfig {
  const RemoteAppConfig({
    required this.maintenanceEnabled,
    required this.maintenanceMessage,
    required this.announcementEnabled,
    required this.announcementTitle,
    required this.announcementBody,
    required this.announcementLevel,
  });

  final bool maintenanceEnabled;
  final String? maintenanceMessage;
  final bool announcementEnabled;
  final String announcementTitle;
  final String announcementBody;
  final String announcementLevel;

  RemoteAppConfig copyWith({
    bool? maintenanceEnabled,
    String? maintenanceMessage,
    bool? announcementEnabled,
    String? announcementTitle,
    String? announcementBody,
    String? announcementLevel,
  }) {
    return RemoteAppConfig(
      maintenanceEnabled: maintenanceEnabled ?? this.maintenanceEnabled,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      announcementEnabled: announcementEnabled ?? this.announcementEnabled,
      announcementTitle: announcementTitle ?? this.announcementTitle,
      announcementBody: announcementBody ?? this.announcementBody,
      announcementLevel: announcementLevel ?? this.announcementLevel,
    );
  }

  static RemoteAppConfig fromJson(Map<String, dynamic> json) {
    return RemoteAppConfig(
      maintenanceEnabled: json['maintenance_enabled'] as bool? ?? false,
      maintenanceMessage: json['maintenance_message'] as String?,
      announcementEnabled: json['announcement_enabled'] as bool? ?? false,
      announcementTitle: (json['announcement_title'] as String?) ?? '',
      announcementBody: (json['announcement_body'] as String?) ?? '',
      announcementLevel: (json['announcement_level'] as String?) ?? 'info',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': 'global',
      'maintenance_enabled': maintenanceEnabled,
      'maintenance_message': maintenanceMessage,
      'announcement_enabled': announcementEnabled,
      'announcement_title': announcementTitle,
      'announcement_body': announcementBody,
      'announcement_level': announcementLevel,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

class AppConfigRepository {
  AppConfigRepository(this._client);

  final SupabaseClient _client;

  Future<RemoteAppConfig> fetch() async {
    final data = await _client
        .from('app_config')
        .select()
        .eq('id', 'global')
        .maybeSingle();

    if (data == null) {
      return const RemoteAppConfig(
        maintenanceEnabled: false,
        maintenanceMessage: null,
        announcementEnabled: false,
        announcementTitle: '',
        announcementBody: '',
        announcementLevel: 'info',
      );
    }

    return RemoteAppConfig.fromJson(data);
  }

  Future<void> save(RemoteAppConfig config) async {
    await _client.from('app_config').upsert(config.toJson());
  }
}

final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  return AppConfigRepository(Supabase.instance.client);
});

final appConfigProvider =
    FutureProvider<RemoteAppConfig>((ref) async {
  return ref.read(appConfigRepositoryProvider).fetch();
});

