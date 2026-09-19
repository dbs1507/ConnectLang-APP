import 'package:flutter/material.dart';

/// Raio leve nos CTAs ([button]) — o bastante pra amaciar o canto, sem
/// virar pílula. Cards de conteúdo usam 16px no próprio componente.
/// O topo do bottom sheet ([sheetTop]) continua mais redondo: é a pista
/// de "isso desliza pra fechar".
abstract final class AppRadius {
  static const none = 0.0;
  static const button = 12.0;
  static const sheetTop = 20.0;
  static const chip = 999.0;

  static const zero = BorderRadius.zero;
  static const buttonShape = BorderRadius.all(Radius.circular(button));
  static const sheet = BorderRadius.vertical(
    top: Radius.circular(sheetTop),
  );
}
