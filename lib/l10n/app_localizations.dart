import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ZTransfer'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Nikon Z Series — USB Tethered Shooting'**
  String get appTagline;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get aboutAuthor;

  /// No description provided for @aboutPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get aboutPlatform;

  /// No description provided for @aboutPlatformValue.
  ///
  /// In en, this message translates to:
  /// **'Android · PTP / MTP'**
  String get aboutPlatformValue;

  /// No description provided for @aboutBuiltWith.
  ///
  /// In en, this message translates to:
  /// **'Built with Flutter'**
  String get aboutBuiltWith;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @noProjectSelected.
  ///
  /// In en, this message translates to:
  /// **'No project selected'**
  String get noProjectSelected;

  /// No description provided for @activeProject.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeProject;

  /// No description provided for @cameraConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get cameraConnected;

  /// No description provided for @cameraConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get cameraConnecting;

  /// No description provided for @cameraError.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get cameraError;

  /// No description provided for @cameraNoCamera.
  ///
  /// In en, this message translates to:
  /// **'No Camera'**
  String get cameraNoCamera;

  /// No description provided for @cameraReady.
  ///
  /// In en, this message translates to:
  /// **'Ready — take a photo'**
  String get cameraReady;

  /// No description provided for @cameraEstablishing.
  ///
  /// In en, this message translates to:
  /// **'Establishing PTP session'**
  String get cameraEstablishing;

  /// No description provided for @cameraUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get cameraUnknownError;

  /// No description provided for @cameraConnectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Connect a Nikon Z via USB'**
  String get cameraConnectPrompt;

  /// No description provided for @cameraConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to camera'**
  String get cameraConnectFailed;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @emptyNoPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos yet — take a photo'**
  String get emptyNoPhotos;

  /// No description provided for @emptyConnectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Connect camera to get started'**
  String get emptyConnectPrompt;

  /// No description provided for @emptyNoSyncedPhotos.
  ///
  /// In en, this message translates to:
  /// **'No synced photos yet'**
  String get emptyNoSyncedPhotos;

  /// No description provided for @rawBadge.
  ///
  /// In en, this message translates to:
  /// **'RAW'**
  String get rawBadge;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'Sync error'**
  String get syncError;

  /// No description provided for @lastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync — {fileName}'**
  String lastSync(String fileName);

  /// No description provided for @syncNoProjectError.
  ///
  /// In en, this message translates to:
  /// **'No active project. Create one first.'**
  String get syncNoProjectError;

  /// No description provided for @autoShowOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-show: ON'**
  String get autoShowOn;

  /// No description provided for @autoShowOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-show: OFF'**
  String get autoShowOff;

  /// No description provided for @phoneGallery.
  ///
  /// In en, this message translates to:
  /// **'Phone Gallery'**
  String get phoneGallery;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAll;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} selected} other{{count} selected}}'**
  String selectedCount(int count);

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete {count} photo?} other{Delete {count} photos?}}'**
  String deleteConfirmTitle(int count);

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteConfirmMessage;

  /// No description provided for @deleteProjectConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this project and all its photos?\n\nThis cannot be undone.'**
  String get deleteProjectConfirm;

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @newProject.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get newProject;

  /// No description provided for @projectNameHint.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get projectNameHint;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameProject.
  ///
  /// In en, this message translates to:
  /// **'Rename Project'**
  String get renameProject;

  /// No description provided for @noProjectsYet.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get noProjectsYet;

  /// No description provided for @createProjectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Create a project to start organizing your photos'**
  String get createProjectPrompt;

  /// No description provided for @createProject.
  ///
  /// In en, this message translates to:
  /// **'Create Project'**
  String get createProject;

  /// No description provided for @deleteProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteProjectTitle(String name);

  /// No description provided for @photoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} photo} other{{count} photos}}'**
  String photoCount(int count);

  /// No description provided for @exifIso.
  ///
  /// In en, this message translates to:
  /// **'ISO'**
  String get exifIso;

  /// No description provided for @exifShutter.
  ///
  /// In en, this message translates to:
  /// **'Shutter'**
  String get exifShutter;

  /// No description provided for @exifAperture.
  ///
  /// In en, this message translates to:
  /// **'Aperture'**
  String get exifAperture;

  /// No description provided for @exifFocal.
  ///
  /// In en, this message translates to:
  /// **'Focal'**
  String get exifFocal;

  /// No description provided for @exifBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get exifBody;

  /// No description provided for @exifDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get exifDate;

  /// No description provided for @exifShutterSuffix.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get exifShutterSuffix;

  /// No description provided for @exifFNumberPrefix.
  ///
  /// In en, this message translates to:
  /// **'f/{aperture}'**
  String exifFNumberPrefix(String aperture);

  /// No description provided for @exifFocalSuffix.
  ///
  /// In en, this message translates to:
  /// **'{focal}mm'**
  String exifFocalSuffix(String focal);

  /// No description provided for @pageCounter.
  ///
  /// In en, this message translates to:
  /// **'{current}/{total}'**
  String pageCounter(int current, int total);

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get unknown;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
