import 'package:file_saver/file_saver.dart';
import 'package:goals_core/model.dart' show Goal;
import 'package:pdf/widgets.dart' show Center, Context, Document, Page, Text;
import 'package:pdf/pdf.dart' show PdfPageFormat;

printGoal(Goal goal) async {
  final doc = Document();

  doc.addPage(Page(
      pageFormat: PdfPageFormat.a4,
      build: (Context context) {
        return Center(
          child: Text('Hello World'),
        );
      }));

  await FileSaver.instance.saveFile(
    name: 'goal_${goal.id}.pdf',
    bytes: await doc.save(),
    ext: "pdf",
    mimeType: MimeType.pdf,
  );
}
