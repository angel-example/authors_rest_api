import 'dart:io';
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_hot/angel_hot.dart';
import 'package:authors_rest_api/authors_rest_api.dart' as authors_rest_api;
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

main() async {
  var hot = new HotReloader(() async {
    var app = new Angel();
    await app.configure(authors_rest_api.configureServer);

    app.logger = new Logger.detached('authors_rest_api')
    ..onRecord.listen((rec) {
      print(rec);
      if (rec.error != null) {
        print(rec.error);
        print(new Chain.forTrace(rec.stackTrace).terse);
      }
    });

    return app;
  }, [
    new Directory('lib'),
  ]);

  var server = await hot.startServer('127.0.0.1', 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
