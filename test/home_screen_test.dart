import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:escrita_de_libras/app.dart';
import 'package:escrita_de_libras/data/base_database.dart';
import 'package:escrita_de_libras/data/user_database.dart';
import 'package:escrita_de_libras/services/sign_image_service.dart';
import 'package:escrita_de_libras/state/app_state.dart';
import 'package:escrita_de_libras/ui/widgets/sign_writing_image.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"/>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late PathProviderPlatform previous;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    await BaseDatabase.instance.close();
    await UserDatabase.instance.close();
    temp = await Directory.systemTemp.createTemp('escrita_de_libras_ui_');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(temp.path);
    SignImageService.instance = SignImageService(
      client: MockClient(
        (request) async => http.Response.bytes(
          _svg.codeUnits,
          200,
          headers: {'content-type': 'image/svg+xml'},
        ),
      ),
    );
    await AppState.instance.init();
  });

  tearDown(() async {
    await BaseDatabase.instance.close();
    await UserDatabase.instance.close();
    PathProviderPlatform.instance = previous;
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  testWidgets('busca um termo e mostra os resultados', (tester) async {
    await tester.runAsync(() async {
      await AppState.instance.search('água');
    });

    await tester.pumpWidget(const EscritaDeLibrasApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verifica que encontrou resultados e exibiu os cards com SignWritingImage
    expect(find.textContaining('resultados'), findsOneWidget);
    expect(find.byType(SignWritingImage), findsWidgets);
  });
}
