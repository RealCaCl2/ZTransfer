import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ztransfer/app_router.dart';
import 'package:ztransfer/core/theme/app_theme.dart';
import 'package:ztransfer/l10n/generated/app_localizations.dart';

/// Root widget.
///
/// Wraps the app in a [ProviderScope] (Riverpod) and [MaterialApp.router]
/// (GoRouter).  Theme defaults to dark — the photography-tool look.
class ZTransferApp extends StatelessWidget {
  const ZTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'ZTransfer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        locale: const Locale('zh'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: appRouter,
      ),
    );
  }
}
