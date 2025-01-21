import 'package:flutter/material.dart';
import 'package:i18n_extension/i18n_extension.dart';

import '../languages/crowdin.dart';
import '../languages/en_us.dart';

List<Language> languages = [
  Language('en', 'US', 'English'),
  Language('ar', 'AR', 'Arabic'),
  Language('pt', 'BR', 'Brazil'),
  Language('it', 'IT', 'Italian'),
  Language('de', 'DE', 'German'),
  Language('ru', 'RU', 'Russian'),
  Language('es', 'ES', 'Spanish'),
  Language('hr', 'HR', 'Croatian'),
  Language('el', 'GR', 'Greek'),
  Language('ko', 'KO', 'Korean'),
  Language('fr', 'FR', 'French'),
  Language('he', 'IL', 'Hebrew'),
  Language('tr', 'TR', 'Turkish'),
  Language('ro', 'RO', 'Romanian'),
  Language('id', 'ID', 'Indonesian'),
  Language('fa', 'IR', 'Persian'),
  Language('pl', 'PL', 'Polish'),
  Language('uk', 'UA', 'Ukrainian'),
  Language('hu', 'HU', 'Hungarian'),
  Language('ur', 'PK', 'Urdu'),
  Language('hi', 'IN', 'Hindi'),
  Language('sk', 'SK', 'Slovak'),
  Language('cs', 'CZ', 'Czech'),
  Language('vi', 'VI', 'Vietnamese'),
  Language('nl', 'NL', 'Dutch'),
  Language('sl', 'SL', 'Slovenian'),
  Language('zh', 'CN', 'Chinese'),
  Language('fil', 'PH', 'Filipino'),
  Language('ast', 'ES', 'Asturian'),
  Language('bul', 'BG', 'Bulgarian'),
  Language('uwu', 'UWU', 'Furry'),
  Language('te', 'IN', 'Telugu'),
];
List<Locale> get supportedLocales => languages.map((l) => l.getLocale).toList();

extension Localization on String {
  static final _t = Translations.byLocale('en_US') + language_en_us + crowdin;

  String get i18n => localize(this, _t);
}

class Language {
  String name;
  String locale;
  String country;
  Language(this.locale, this.country, this.name);

  Locale get getLocale => Locale(locale, country);
}
