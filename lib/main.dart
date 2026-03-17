import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/data/imperium_app_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDirectory = await getApplicationSupportDirectory();
  final repository = await ImperiumAppRepository.open(
    storagePath: appDirectory.path,
  );

  runApp(ImperiumSuiApp(repository: repository));
}
