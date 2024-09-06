import 'package:file_saver/file_saver.dart';
import 'package:pdf/widgets.dart' show Document;

printGoal(Function(Document) builder) async {
  final doc = Document();

  await builder(doc);

  await FileSaver.instance.saveFile(
    name: 'notes',
    bytes: await doc.save(),
    ext: "pdf",
    mimeType: MimeType.pdf,
  );
}
