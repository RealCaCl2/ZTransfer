// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ZTransfer';

  @override
  String get appTagline => 'Nikon Z Series — USB Tethered Shooting';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutAuthor => 'Author';

  @override
  String get aboutPlatform => 'Platform';

  @override
  String get aboutPlatformValue => 'Android · PTP / MTP';

  @override
  String get aboutBuiltWith => 'Built with Flutter';

  @override
  String get photos => 'Photos';

  @override
  String get noProjectSelected => 'No project selected';

  @override
  String get activeProject => 'Active';

  @override
  String get cameraConnected => 'Connected';

  @override
  String get cameraConnecting => 'Connecting…';

  @override
  String get cameraError => 'Connection Error';

  @override
  String get cameraNoCamera => 'No Camera';

  @override
  String get cameraReady => 'Ready — take a photo';

  @override
  String get cameraEstablishing => 'Establishing PTP session';

  @override
  String get cameraUnknownError => 'Unknown error';

  @override
  String get cameraConnectPrompt => 'Connect a Nikon Z via USB';

  @override
  String get cameraConnectFailed => 'Failed to connect to camera';

  @override
  String get connect => 'Connect';

  @override
  String get retry => 'Retry';

  @override
  String get emptyNoPhotos => 'No photos yet — take a photo';

  @override
  String get emptyConnectPrompt => 'Connect camera to get started';

  @override
  String get emptyNoSyncedPhotos => 'No synced photos yet';

  @override
  String get rawBadge => 'RAW';

  @override
  String get syncing => 'Syncing…';

  @override
  String get syncError => 'Sync error';

  @override
  String lastSync(String fileName) {
    return 'Last sync — $fileName';
  }

  @override
  String get syncNoProjectError => 'No active project. Create one first.';

  @override
  String get autoShowOn => 'Auto-show: ON';

  @override
  String get autoShowOff => 'Auto-show: OFF';

  @override
  String get phoneGallery => 'Phone Gallery';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get deleteAll => 'Delete All';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '$count selected',
    );
    return '$_temp0';
  }

  @override
  String deleteConfirmTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count photos?',
      one: 'Delete $count photo?',
    );
    return '$_temp0';
  }

  @override
  String get deleteConfirmMessage => 'This cannot be undone.';

  @override
  String get deleteProjectConfirm => 'Delete this project and all its photos?\n\nThis cannot be undone.';

  @override
  String get projects => 'Projects';

  @override
  String get newProject => 'New Project';

  @override
  String get projectNameHint => 'Project name';

  @override
  String get create => 'Create';

  @override
  String get rename => 'Rename';

  @override
  String get renameProject => 'Rename Project';

  @override
  String get noProjectsYet => 'No projects yet';

  @override
  String get createProjectPrompt => 'Create a project to start organizing your photos';

  @override
  String get createProject => 'Create Project';

  @override
  String deleteProjectTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '$count photo',
    );
    return '$_temp0';
  }

  @override
  String get exifIso => 'ISO';

  @override
  String get exifShutter => 'Shutter';

  @override
  String get exifAperture => 'Aperture';

  @override
  String get exifFocal => 'Focal';

  @override
  String get exifBody => 'Body';

  @override
  String get exifDate => 'Date';

  @override
  String get exifShutterSuffix => 's';

  @override
  String exifFNumberPrefix(String aperture) {
    return 'f/$aperture';
  }

  @override
  String exifFocalSuffix(String focal) {
    return '${focal}mm';
  }

  @override
  String pageCounter(int current, int total) {
    return '$current/$total';
  }

  @override
  String get unknown => 'unknown';
}
