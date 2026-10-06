/// Formatage partagé des montants en francs CFA.
///
/// Le séparateur de milliers est une virgule et le suffixe est « FCFA », parce que
/// c'est ce que le commerçant lit sur ses tickets et ce que les autres écrans de
/// l'application écrivent déjà. Un montant affiché à un endroit et differently à un
/// autre est un montant que le commerçant doit vérifier.
///
/// Les montants vocaux sont des `double` parce que Firestore renvoie tout nombre en
/// `double` et que les prix sont stockés ainsi, alors que les montants d'écran sont
/// des `int`. Les deux fonctions existent pour que chacun utilise la sienne sans
/// convertir à la main.
library;

/// [amount] francs, avec séparateurs de milliers et le suffixe, par exemple
/// « 27,500 FCFA ».
///
/// Le paramètre est un [num] et non un [double] parce que les deux existent dans
/// l'application : les prix viennent de Firestore en `double`, et les montants
/// d'écran sont des entiers. Les accepter tous les deux évite à chaque appelant de
/// convertir un montant qui est déjà juste.
///
/// Le montant est arrondi avant d'être formaté : un prix en francs n'a pas de
/// centimes, et afficher « 2,500.4 FCFA » sur une facture est une faute.
String formatCfa(num amount, {String suffix = 'FCFA'}) =>
    '${formatThousands(amount)} $suffix';

/// [amount] avec des virgules tous les trois chiffres, par exemple « 2 500 ».
///
/// Le montant est arrondi et non tronqué : arrondir 2 999,6 en « 3 000 » est
/// correct, le tronquer en « 2 999 » ferait un montant que le commerçant n'a pas.
String formatThousands(num amount) {
  final String digits = amount.round().abs().toString();
  final StringBuffer buffer = StringBuffer(amount < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}