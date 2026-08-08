import 'dart:io';

/// Interfaces whose addresses no phone on the Wi-Fi can reach: VPN tunnels,
/// container bridges and hypervisor adapters. Matched on Linux and Windows
/// names alike.
final _virtualInterface = RegExp(
  r'^(lo|tun|tap|wg|ppp|docker|br-|virbr|veth|lxc|zt|'
  r'vethernet|vmware|vbox|virtualbox|hyper-v|npcap|'
  r'cloudflare|proton|nordlynx|tailscale)',
  caseSensitive: false,
);

final _privateIpv4 = RegExp(r'^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)');

/// IPv4 addresses another device on the same network can actually reach.
///
/// Private ranges come first: on a machine with a VPN up, the public-looking
/// tunnel address is the one that does not work for a phone next to you.
Future<List<String>> lanIpv4Addresses() async {
  final List<NetworkInterface> interfaces;
  try {
    interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
  } on SocketException {
    return const [];
  }

  final addresses = <String>[];
  for (final interface in interfaces) {
    if (_virtualInterface.hasMatch(interface.name)) continue;
    for (final address in interface.addresses) {
      if (!address.isLoopback && !addresses.contains(address.address)) {
        addresses.add(address.address);
      }
    }
  }

  final private = addresses.where(_privateIpv4.hasMatch).toList();
  return private.isNotEmpty ? private : addresses;
}
