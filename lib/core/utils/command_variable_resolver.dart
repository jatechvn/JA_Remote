import '../../data/models/managed_device.dart';

/// Utility to resolve dynamic placeholders in remote commands or scripts.
///
/// Supported variables:
/// - `{{IP}}`: Target device IPv4/IPv6 address
/// - `{{HOSTNAME}}`: Target device hostname
/// - `{{NAME}}`: Target device friendly name
/// - `{{GROUP}}`: Target device group (e.g. L6, Factory)
/// - `{{MAC}}`: Target device MAC address (or empty string if none)
/// - `{{OS}}`: Target device Operating System
/// - `{{PORT}}`: SSH or remote management port
/// - `{{USER}}`: Specified username or device username
class CommandVariableResolver {
  /// Resolves placeholders in [template] for the given [device].
  /// Variables can be case-insensitive (e.g. `{{ip}}` or `{{IP}}`).
  static String resolve(
    String template,
    ManagedDevice device, {
    String? username,
  }) {
    if (template.isEmpty) return template;

    final user = username ?? device.username ?? '';

    // Regex to match {{VARIABLE}}
    final pattern = RegExp(r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}');

    return template.replaceAllMapped(pattern, (match) {
      final key = match.group(1)?.toUpperCase();
      switch (key) {
        case 'IP':
          return device.ip;
        case 'HOSTNAME':
          return device.hostname;
        case 'NAME':
          return device.name;
        case 'GROUP':
          return device.group;
        case 'MAC':
          return device.mac ?? '';
        case 'OS':
          return device.os;
        case 'PORT':
          return device.sshPort.toString();
        case 'USER':
        case 'USERNAME':
          return user;
        default:
          return match.group(0)!; // Keep unresolved tokens intact
      }
    });
  }

  /// Available variable chips for UI templates.
  static const List<Map<String, String>> availableVariables = [
    {'token': '{{IP}}', 'label': 'IP Address', 'desc': 'Target device IP'},
    {'token': '{{HOSTNAME}}', 'label': 'Hostname', 'desc': 'Target hostname'},
    {'token': '{{NAME}}', 'label': 'Device Name', 'desc': 'Friendly name'},
    {'token': '{{GROUP}}', 'label': 'Group', 'desc': 'Assigned device group'},
    {'token': '{{MAC}}', 'label': 'MAC', 'desc': 'MAC physical address'},
    {'token': '{{USER}}', 'label': 'Username', 'desc': 'Login username'},
  ];
}
