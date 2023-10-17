import 'package:intl/intl.dart' show DateFormat;

formatDate(DateTime date) {
  return DateFormat('yyyy.MM.dd.').format(date) +
      DateFormat('EE').format(date).substring(0, 2).toUpperCase();
}
