import 'dart:io';

/// Interfaces cuyas direcciones no alcanza ningún celular de la Wi-Fi: túneles
/// VPN, puentes de contenedores y adaptadores de hipervisor. El patrón cubre
/// por igual los nombres de Linux y los de Windows.
final _virtualInterface = RegExp(
  r'^(lo|tun|tap|wg|ppp|docker|br-|virbr|veth|lxc|zt|'
  r'vethernet|vmware|vbox|virtualbox|hyper-v|npcap|'
  r'cloudflare|proton|nordlynx|tailscale)',
  caseSensitive: false,
);

final _privateIpv4 = RegExp(r'^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)');

/// Las direcciones IPv4 que otro dispositivo de la misma red alcanza de verdad.
///
/// Los rangos privados van primero: en una máquina con una VPN levantada, la
/// dirección del túnel, que parece pública, es justo la que no funciona para un
/// celular que está a tu lado.
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
