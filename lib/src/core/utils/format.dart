import 'package:intl/intl.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$', decimalDigits: 2);

String money(num value) => _brl.format(value).replaceAll(' ', ' ');

/// "+ R$ 4,00" para preços adicionais; vazio quando grátis.
String moneyDelta(num value) => value <= 0 ? 'Grátis' : '+ ${money(value)}';

String plural(int n, String singular, String pluralForm) => '$n ${n == 1 ? singular : pluralForm}';

String twoDigits(int n) => n.toString().padLeft(2, '0');

String hourLabel(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  return m == 0 ? '${h}h' : '${h}h${twoDigits(m)}';
}

String timeOf(DateTime d) => '${twoDigits(d.hour)}:${twoDigits(d.minute)}';

String greeting(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Boa noite';
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
}

String elapsed(DateTime since, DateTime now) {
  final d = now.difference(since);
  if (d.inMinutes < 1) return 'agora';
  if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return m == 0 ? 'há ${h}h' : 'há ${h}h${twoDigits(m)}';
}

/// Remove acentos para busca tolerante ("cafe" encontra "Café").
String normalize(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final b = StringBuffer();
  for (final ch in s.runes) {
    final c = String.fromCharCode(ch);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString().toLowerCase();
}
