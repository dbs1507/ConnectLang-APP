import 'package:flutter/material.dart';

/// Tokens de cor extraídos direto do `globals.css` da landing page
/// (`Connections-Landing-Page/src/app/globals.css`) — fonte de verdade da
/// marca. Teal é o acento funcional; o amarelo é a identidade da LIA.
abstract final class AppColors {
  /// Teal da marca — único acento usado em botões primários, estado ativo
  /// da navegação e barra de progresso.
  static const primary = Color(0xFF349993);

  /// Identidade da LIA — amarelo `#EBFF8C`. Forte no chip e na espera;
  /// diluído ([liaSoft]) na barra e no Coach.
  static const lia = Color(0xFFEBFF8C);
  static final liaSoft = Color.lerp(background, lia, 0.16)!;

  /// Roxo do atalho flutuante do Caderno.
  static const notebook = Color(0xFF8EA2FF);

  /// Fundo suave do teal, usado só atrás de grifos/realces de texto.
  static const primarySoft = Color(0xFF48A39E);

  /// Terracota — reservado pra badges promocionais/alertas pontuais, não
  /// pra ações do dia a dia.
  static const terracotta = Color(0xFFE9542C);

  /// Verde-limão da marca — só em contexto de hero/onboarding, nunca em UI
  /// funcional recorrente.
  static const yellowLime = Color(0xFFAAE467);

  /// Amarelo da LIA — tom cheio.
  static const yellowPale = lia;

  /// [lia] a 16% sobre branco — barra de funções e telas da LIA.
  static final yellowPale16 = liaSoft;

  /// Fundo do hero/onboarding: amarelo pálido bem diluído sobre branco.
  static const heroSurface = Color(0xFFFCFFED);

  static const background = Color(0xFFFFFFFF);
  static const backgroundMuted = Color(0xFFF9FAFB);

  /// Texto de corpo (parágrafos, descrições).
  static const foreground = Color(0xFF6B6761);

  /// Texto de título (h1–h4 no site).
  static const heading = Color(0xFF1A1A1A);

  /// Texto de itens de navegação.
  static const navText = Color(0xFF504D49);

  static const border = Color(0xFFE5E7EB);

  /// Botão "preto" (`bg-black/90` no site) — alternativa neutra ao teal
  /// pra CTAs que não devem competir com o acento funcional.
  static const buttonBlack = Color(0xFF1A1A1A);

  static const destructive = Color(0xFFD64545);
  static const success = Color(0xFF3F8F5C);
}
