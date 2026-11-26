import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/settings.dart';
import 'services/app_state.dart';
import 'services/media_controls.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

final app = AppState();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  runApp(const MawaqeetyApp());
  await MediaControls.init();
  await app.init();
}

class MawaqeetyApp extends StatelessWidget {
  const MawaqeetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final mode = switch (app.settings.theme) {
          ThemeChoice.dark => ThemeMode.dark,
          ThemeChoice.light => ThemeMode.light,
          ThemeChoice.system => ThemeMode.system,
        };
        final palette = paletteById(app.settings.palette);
        AppColors.current = palette;
        return MaterialApp(
          title: 'مواقيتي',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light, palette),
          darkTheme: buildTheme(Brightness.dark, palette),
          themeMode: mode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: app.ready ? const HomeShell() : const _Splash(),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/images/logo.png', width: 96),
            const SizedBox(height: 16),
            const Text('مواقيتي', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
            Text('صلاتك في وقتها', style: TextStyle(color: AppColors.gold, fontSize: 15)),
          ]),
        ),
      );
}
