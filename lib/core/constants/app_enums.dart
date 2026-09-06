import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';

/// The three target user groups of SUMPAY.
enum UserRole {
  user('Community Member', Symbols.person_rounded),
  official('Barangay Official', Symbols.shield_person_rounded),
  admin('Administrator', Symbols.admin_panel_settings_rounded);

  const UserRole(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Safely parses a role string, mapping legacy values ('resident',
  /// 'volunteer') from older accounts/records onto the unified [user] role so
  /// existing Supabase rows and seeds keep working without a migration.
  static UserRole fromName(String? raw) {
    switch (raw) {
      case 'resident':
      case 'volunteer':
      case 'user':
        return UserRole.user;
      case 'official':
        return UserRole.official;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.user;
    }
  }

  bool get canBroadcast =>
      this == UserRole.official || this == UserRole.admin;

  /// Whether this account can act as a responder (accept SOS). Every community
  /// member and official can respond; admins manage the system.
  bool get canRespond =>
      this == UserRole.user || this == UserRole.official;

  bool get hasAssignments =>
      this == UserRole.user || this == UserRole.official;

  /// Admin-only: manage accounts and roles.
  bool get canManageUsers => this == UserRole.admin;

  /// Admin-only: approve or reject pending accounts.
  bool get canApproveUsers => this == UserRole.admin;

  /// Whether a newly registered user of this role must be approved by an
  /// administrator before their account becomes active. Officials require
  /// approval; community members (and admins) do not.
  bool get requiresApproval => this == UserRole.official;
}

/// Approval state of a user account, managed by an administrator.
enum AccountStatus {
  active('Active', AppColors.success, Symbols.check_circle_rounded),
  pending('Pending approval', AppColors.warning, Symbols.hourglass_top_rounded),
  rejected('Rejected', AppColors.danger, Symbols.cancel_rounded),
  deactivated('Deactivated', AppColors.textSecondary, Symbols.block_rounded);

  const AccountStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  bool get isActive => this == AccountStatus.active;
  bool get isPending => this == AccountStatus.pending;
}

/// Categories available on the SOS screen.
enum EmergencyType {
  medical('Medical', Symbols.medical_services_rounded, Color(0xFF2E9E5B),
      PriorityLevel.critical),
  fire('Fire', Symbols.local_fire_department_rounded, Color(0xFFE8590C),
      PriorityLevel.critical),
  rescue('Rescue', Symbols.support_rounded, Color(0xFF1668C1),
      PriorityLevel.critical),
  flood('Flood', Symbols.flood_rounded, Color(0xFF00A8C6),
      PriorityLevel.high),
  earthquake('Earthquake', Symbols.earthquake_rounded, Color(0xFF8D6E63),
      PriorityLevel.critical),
  supply('Supply', Symbols.inventory_2_rounded, Color(0xFF7B5AC6),
      PriorityLevel.normal),
  custom('Custom', Symbols.edit_note_rounded, Color(0xFF616E7C),
      PriorityLevel.high);

  const EmergencyType(this.label, this.icon, this.color, this.defaultPriority);

  final String label;
  final IconData icon;
  final Color color;

  /// A translucent tint of [color] for backgrounds/chips, so the strict
  /// per-type colour is used consistently across the app.
  Color get softColor => Color.alphaBlend(color.withValues(alpha: 0.12),
      const Color(0xFFFFFFFF));

  /// Priority automatically applied when this category is chosen, so residents
  /// never pick a priority manually.
  final PriorityLevel defaultPriority;

  /// Categories a resident may choose when raising an SOS. Excludes [custom],
  /// which is retained in the enum for compatibility but not offered in the
  /// resident SOS flow (predefined categories only).
  static List<EmergencyType> get residentSelectable => <EmergencyType>[
        EmergencyType.medical,
        EmergencyType.fire,
        EmergencyType.rescue,
        EmergencyType.flood,
        EmergencyType.earthquake,
        EmergencyType.supply,
      ];
}

/// Priority applied to SOS requests and messages.
enum PriorityLevel {
  low('Low', AppColors.success, AppColors.successSoft),
  normal('Normal', AppColors.info, AppColors.infoSoft),
  high('High', AppColors.warning, AppColors.warningSoft),
  critical('Critical', AppColors.emergency, AppColors.dangerSoft);

  const PriorityLevel(this.label, this.color, this.softColor);

  final String label;
  final Color color;
  final Color softColor;
}

/// Delivery state of a mesh/LoRa transmitted payload.
enum DeliveryStatus {
  queued('Queued', Symbols.schedule_rounded),
  sending('Sending', Symbols.upload_rounded),
  relayed('Relayed', Symbols.swap_horiz_rounded),
  delivered('Delivered', Symbols.done_all_rounded),
  failed('Failed', Symbols.error_rounded);

  const DeliveryStatus(this.label, this.icon);

  final String label;
  final IconData icon;

  Color get color => switch (this) {
        DeliveryStatus.queued => AppColors.textSecondary,
        DeliveryStatus.sending => AppColors.info,
        DeliveryStatus.relayed => AppColors.warning,
        DeliveryStatus.delivered => AppColors.success,
        DeliveryStatus.failed => AppColors.danger,
      };
}

/// Transport path currently carrying traffic.
enum LinkMode {
  loRa('SUMPAY Network', Symbols.settings_input_antenna_rounded),
  mesh('Nearby Devices', Symbols.hub_rounded),
  internet('Internet', Symbols.cloud_done_rounded),
  offline('Offline', Symbols.cloud_off_rounded);

  const LinkMode(this.label, this.icon);

  final String label;
  final IconData icon;

  Color get color => switch (this) {
        LinkMode.loRa => AppColors.success,
        LinkMode.mesh => AppColors.warning,
        LinkMode.internet => AppColors.info,
        LinkMode.offline => AppColors.danger,
      };
}

/// Health of a gateway or repeater node.
enum NodeStatus {
  online('Online', AppColors.success),
  degraded('Degraded', AppColors.warning),
  offline('Offline', AppColors.danger);

  const NodeStatus(this.label, this.color);

  final String label;
  final Color color;
}

/// Lifecycle of a volunteer assignment.
enum TaskStatus {
  pending('Pending', AppColors.textSecondary),
  accepted('Accepted', AppColors.info),
  inProgress('In Progress', AppColors.warning),
  completed('Completed', AppColors.success);

  const TaskStatus(this.label, this.color);

  final String label;
  final Color color;
}

/// Lifecycle of an emergency incident.
enum IncidentStatus {
  active('Active', AppColors.emergency),
  responding('Responding', AppColors.warning),
  resolved('Resolved', AppColors.success),
  cancelled('Cancelled', AppColors.textSecondary);

  const IncidentStatus(this.label, this.color);

  final String label;
  final Color color;
}

/// Broadcast severity used by the barangay command node.
enum BroadcastSeverity {
  advisory('Advisory', AppColors.info, AppColors.infoSoft),
  warning('Warning', AppColors.warning, AppColors.warningSoft),
  alert('Alert', AppColors.emergency, AppColors.dangerSoft);

  const BroadcastSeverity(this.label, this.color, this.softColor);

  final String label;
  final Color color;
  final Color softColor;
}

/// Categories used by the notification centre.
enum NotificationKind {
  broadcast('Broadcast', Symbols.campaign_rounded, AppColors.info),
  sos('SOS Update', Symbols.sos_rounded, AppColors.emergency),
  message('Message', Symbols.forum_rounded, AppColors.textSecondary),
  network('Network', Symbols.router_rounded, AppColors.warning),
  task('Assignment', Symbols.assignment_turned_in_rounded, AppColors.success);

  const NotificationKind(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// High-level state of the local Nearby Connections engine on this device.
///
/// Drives the Nearby Device screen's status banner. Discovery and advertising
/// are tracked separately in the provider; this enum captures the overall mode
/// the device is presenting to its neighbours.
enum NearbyEngineState {
  idle('Idle', AppColors.textSecondary, Symbols.wifi_tethering_off_rounded),
  advertising('Advertising', AppColors.info, Symbols.wifi_tethering_rounded),
  discovering('Discovering', AppColors.warning, Symbols.radar_rounded),
  active('Advertising & discovering', AppColors.success, Symbols.hub_rounded);

  const NearbyEngineState(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

/// Lifecycle of a single peer connection managed by [NearbyService].
enum PeerConnectionState {
  found('Found', AppColors.textSecondary, Symbols.devices_other_rounded),
  requesting('Requesting', AppColors.info, Symbols.pending_rounded),
  pending('Awaiting acceptance', AppColors.warning, Symbols.hourglass_top_rounded),
  connected('Connected', AppColors.success, Symbols.link_rounded),
  disconnected('Disconnected', AppColors.textSecondary, Symbols.link_off_rounded),
  rejected('Rejected', AppColors.danger, Symbols.block_rounded),
  error('Error', AppColors.danger, Symbols.error_rounded);

  const PeerConnectionState(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  bool get isConnected => this == PeerConnectionState.connected;

  bool get isBusy =>
      this == PeerConnectionState.requesting ||
      this == PeerConnectionState.pending;
}
