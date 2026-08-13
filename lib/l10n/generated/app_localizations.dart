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
/// import 'generated/app_localizations.dart';
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
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
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
  /// **'Auto-fullscreen new photos · On'**
  String get autoShowOn;

  /// No description provided for @autoShowOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-fullscreen new photos · Off'**
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

  /// No description provided for @receivePhotos.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receivePhotos;

  /// No description provided for @stopReceiving.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopReceiving;

  /// No description provided for @scanNetworkCamera.
  ///
  /// In en, this message translates to:
  /// **'Scan for cameras'**
  String get scanNetworkCamera;

  /// No description provided for @scanNetworkCameraInProgress.
  ///
  /// In en, this message translates to:
  /// **'Scanning network...'**
  String get scanNetworkCameraInProgress;

  /// No description provided for @scanCurrentNetworkStatus.
  ///
  /// In en, this message translates to:
  /// **'Scanning the current Wi-Fi and hotspot networks...'**
  String get scanCurrentNetworkStatus;

  /// No description provided for @scanNotFoundHint.
  ///
  /// In en, this message translates to:
  /// **'No camera found. Make sure Connect to computer is enabled and the camera is on the same network.'**
  String get scanNotFoundHint;

  /// No description provided for @scanTimeoutHint.
  ///
  /// In en, this message translates to:
  /// **'Scan timed out. Check the network and retry, or enter the camera IP manually.'**
  String get scanTimeoutHint;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String scanFailed(String error);

  /// No description provided for @pairingWaitingCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for camera'**
  String get pairingWaitingCameraTitle;

  /// No description provided for @pairingRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera pairing request'**
  String get pairingRequestTitle;

  /// No description provided for @pairingRequestSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Pairing request submitted'**
  String get pairingRequestSubmittedTitle;

  /// No description provided for @pairingBeforeSubmitInstructions.
  ///
  /// In en, this message translates to:
  /// **'Make sure the pairing code on the camera matches the code above.\nSubmit the code below first, then press OK on the camera.'**
  String get pairingBeforeSubmitInstructions;

  /// No description provided for @pairingAfterSubmitInstructions.
  ///
  /// In en, this message translates to:
  /// **'The pairing request has been sent.\nNow press OK on the camera while the app waits for confirmation.'**
  String get pairingAfterSubmitInstructions;

  /// No description provided for @pairingSubmitCode.
  ///
  /// In en, this message translates to:
  /// **'Submit pairing code'**
  String get pairingSubmitCode;

  /// No description provided for @pairingWaitingCameraConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for camera OK'**
  String get pairingWaitingCameraConfirmation;

  /// No description provided for @pairingFailed.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed'**
  String get pairingFailed;

  /// No description provided for @pairingReconnectingStatus.
  ///
  /// In en, this message translates to:
  /// **'Pairing succeeded. Reconnecting to the camera...'**
  String get pairingReconnectingStatus;

  /// No description provided for @pairingConfirmException.
  ///
  /// In en, this message translates to:
  /// **'Confirmation failed: {error}'**
  String pairingConfirmException(String error);

  /// No description provided for @transferListeningStarted.
  ///
  /// In en, this message translates to:
  /// **'Listening for photos selected on the camera'**
  String get transferListeningStarted;

  /// No description provided for @transferAlreadyListening.
  ///
  /// In en, this message translates to:
  /// **'Photo receiving is already active'**
  String get transferAlreadyListening;

  /// No description provided for @transferListeningStopped.
  ///
  /// In en, this message translates to:
  /// **'Photo receiving stopped'**
  String get transferListeningStopped;

  /// No description provided for @transferNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Connect a paired camera before receiving photos'**
  String get transferNotConnected;

  /// No description provided for @transferListeningActive.
  ///
  /// In en, this message translates to:
  /// **'LISTENING FOR CAMERA'**
  String get transferListeningActive;

  /// No description provided for @transferWaitingForCamera.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a photo selected on the camera'**
  String get transferWaitingForCamera;

  /// No description provided for @transferReceivingProgress.
  ///
  /// In en, this message translates to:
  /// **'Receiving photo · {progress}%'**
  String transferReceivingProgress(int progress);

  /// No description provided for @transferRate.
  ///
  /// In en, this message translates to:
  /// **'Speed {rate}'**
  String transferRate(String rate);

  /// No description provided for @transferLastRate.
  ///
  /// In en, this message translates to:
  /// **'Last {rate}'**
  String transferLastRate(String rate);

  /// No description provided for @tutorialTitle.
  ///
  /// In en, this message translates to:
  /// **'User Guide'**
  String get tutorialTitle;

  /// No description provided for @wirelessTutorialLink.
  ///
  /// In en, this message translates to:
  /// **'Wireless connection guide'**
  String get wirelessTutorialLink;

  /// No description provided for @tutorialHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Two things before you start'**
  String get tutorialHeroTitle;

  /// No description provided for @tutorialHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Create or select a project to store received photos. For Wi-Fi, put the camera on its waiting-for-pairing screen before scanning in the app.'**
  String get tutorialHeroBody;

  /// No description provided for @tutorialWirelessTitle.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi connection'**
  String get tutorialWirelessTitle;

  /// No description provided for @tutorialWirelessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The first connection requires pairing. Saved cameras can reconnect directly later.'**
  String get tutorialWirelessSubtitle;

  /// No description provided for @tutorialChooseCameraType.
  ///
  /// In en, this message translates to:
  /// **'Choose the menu type shown by your camera'**
  String get tutorialChooseCameraType;

  /// No description provided for @tutorialModernType.
  ///
  /// In en, this message translates to:
  /// **'Has Connection type'**
  String get tutorialModernType;

  /// No description provided for @tutorialClassicType.
  ///
  /// In en, this message translates to:
  /// **'No Connection type'**
  String get tutorialClassicType;

  /// No description provided for @tutorialModernModels.
  ///
  /// In en, this message translates to:
  /// **'Examples: ZR / Z9 / Z8 / Z6III / Zf / Z5II / Z50II'**
  String get tutorialModernModels;

  /// No description provided for @tutorialClassicModels.
  ///
  /// In en, this message translates to:
  /// **'Examples: Z6 / Z7 / Z6II / Z7II / Z5 / Z50 / Zfc / Z30'**
  String get tutorialClassicModels;

  /// No description provided for @tutorialCameraTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Not sure? Open Connect to computer. Choose the first option if Connection type is present; otherwise choose the second.'**
  String get tutorialCameraTypeHint;

  /// No description provided for @tutorialMenuPath.
  ///
  /// In en, this message translates to:
  /// **'CAMERA MENU PATH'**
  String get tutorialMenuPath;

  /// No description provided for @tutorialModernMenuPath.
  ///
  /// In en, this message translates to:
  /// **'MENU → Network menu → Connect to computer → Connection type → Image transfer → Network settings'**
  String get tutorialModernMenuPath;

  /// No description provided for @tutorialClassicMenuPath.
  ///
  /// In en, this message translates to:
  /// **'MENU → Setup menu (wrench) → Connect to PC / Connect to computer → Network settings'**
  String get tutorialClassicMenuPath;

  /// No description provided for @tutorialModernStep1.
  ///
  /// In en, this message translates to:
  /// **'Press MENU, open Network menu, then select Connect to computer.'**
  String get tutorialModernStep1;

  /// No description provided for @tutorialModernStep2.
  ///
  /// In en, this message translates to:
  /// **'Open Connection type and select Image transfer. Do not select Camera control.'**
  String get tutorialModernStep2;

  /// No description provided for @tutorialModernStep3.
  ///
  /// In en, this message translates to:
  /// **'Open Network settings, then create a new profile or select an existing one.'**
  String get tutorialModernStep3;

  /// No description provided for @tutorialModernStep4.
  ///
  /// In en, this message translates to:
  /// **'Connect the camera to the same Wi-Fi as the phone, or connect it to the phone hotspot.'**
  String get tutorialModernStep4;

  /// No description provided for @tutorialModernStep5.
  ///
  /// In en, this message translates to:
  /// **'Use Obtain automatically / Auto for the IP address, then continue pairing.'**
  String get tutorialModernStep5;

  /// No description provided for @tutorialModernStep6.
  ///
  /// In en, this message translates to:
  /// **'Wait until the camera shows its name and enters the pairing screen, then return to the app and tap Scan for cameras.'**
  String get tutorialModernStep6;

  /// No description provided for @tutorialClassicStep1.
  ///
  /// In en, this message translates to:
  /// **'Press MENU, open Setup menu (wrench), then select Connect to PC / Connect to computer.'**
  String get tutorialClassicStep1;

  /// No description provided for @tutorialClassicStep2.
  ///
  /// In en, this message translates to:
  /// **'Open Network settings, then create a new profile or select an existing one.'**
  String get tutorialClassicStep2;

  /// No description provided for @tutorialClassicStep3.
  ///
  /// In en, this message translates to:
  /// **'Connect the camera to the same Wi-Fi as the phone, or connect it to the phone hotspot.'**
  String get tutorialClassicStep3;

  /// No description provided for @tutorialClassicStep4.
  ///
  /// In en, this message translates to:
  /// **'Use Obtain automatically / Auto for the IP address, then continue pairing.'**
  String get tutorialClassicStep4;

  /// No description provided for @tutorialClassicStep5.
  ///
  /// In en, this message translates to:
  /// **'Wait until the camera shows its name and enters the pairing screen, then return to the app and tap Scan for cameras.'**
  String get tutorialClassicStep5;

  /// No description provided for @tutorialRequiredScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'The camera must reach this screen'**
  String get tutorialRequiredScreenTitle;

  /// No description provided for @tutorialModernRequiredScreen.
  ///
  /// In en, this message translates to:
  /// **'Connection type is set to Image transfer, and the camera screen shows the camera name with a waiting-for-pairing message.'**
  String get tutorialModernRequiredScreen;

  /// No description provided for @tutorialClassicRequiredScreen.
  ///
  /// In en, this message translates to:
  /// **'The camera screen shows the camera name and indicates that it is waiting for the computer to start pairing.'**
  String get tutorialClassicRequiredScreen;

  /// No description provided for @tutorialPairingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pairing code sequence'**
  String get tutorialPairingTitle;

  /// No description provided for @tutorialPairingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow this order during the first connection'**
  String get tutorialPairingSubtitle;

  /// No description provided for @tutorialPairingStep1.
  ///
  /// In en, this message translates to:
  /// **'Select the camera in the scan results and wait for the app to show a four-digit pairing code.'**
  String get tutorialPairingStep1;

  /// No description provided for @tutorialPairingStep2.
  ///
  /// In en, this message translates to:
  /// **'Confirm that the four-digit codes shown by the app and camera match.'**
  String get tutorialPairingStep2;

  /// No description provided for @tutorialPairingStep3.
  ///
  /// In en, this message translates to:
  /// **'Tap Submit pairing code in the app first.'**
  String get tutorialPairingStep3;

  /// No description provided for @tutorialPairingStep4.
  ///
  /// In en, this message translates to:
  /// **'After Waiting for camera appears, press OK on the camera (J/OK on some models).'**
  String get tutorialPairingStep4;

  /// No description provided for @tutorialPairingStep5.
  ///
  /// In en, this message translates to:
  /// **'Keep the camera on Connect to computer until the dialog closes automatically and the app shows Connected.'**
  String get tutorialPairingStep5;

  /// No description provided for @tutorialReceivingTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive photos'**
  String get tutorialReceivingTitle;

  /// No description provided for @tutorialReceivingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The camera connection and the receiving listener are separate states'**
  String get tutorialReceivingSubtitle;

  /// No description provided for @tutorialReceivingStep1.
  ///
  /// In en, this message translates to:
  /// **'Create or select an active project. Received photos are saved into that project.'**
  String get tutorialReceivingStep1;

  /// No description provided for @tutorialReceivingStep2.
  ///
  /// In en, this message translates to:
  /// **'After the camera connects, tap Receive and wait for the prominent listening indicator.'**
  String get tutorialReceivingStep2;

  /// No description provided for @tutorialReceivingStep3.
  ///
  /// In en, this message translates to:
  /// **'On the camera playback screen, select photos and choose Send to computer. The exact menu wording may differ by model.'**
  String get tutorialReceivingStep3;

  /// No description provided for @tutorialReceivingStep4.
  ///
  /// In en, this message translates to:
  /// **'Stop ends photo listening only and keeps the camera connected. Use Disconnect when you want to end the connection.'**
  String get tutorialReceivingStep4;

  /// No description provided for @tutorialUsbTitle.
  ///
  /// In en, this message translates to:
  /// **'USB connection'**
  String get tutorialUsbTitle;

  /// No description provided for @tutorialUsbSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use an OTG-capable data cable for the most direct connection'**
  String get tutorialUsbSubtitle;

  /// No description provided for @tutorialUsbStep1.
  ///
  /// In en, this message translates to:
  /// **'Connect the Nikon camera to the phone with an OTG-capable data cable.'**
  String get tutorialUsbStep1;

  /// No description provided for @tutorialUsbStep2.
  ///
  /// In en, this message translates to:
  /// **'Unlock the phone and allow ZTransfer to access the USB device when Android asks.'**
  String get tutorialUsbStep2;

  /// No description provided for @tutorialUsbStep3.
  ///
  /// In en, this message translates to:
  /// **'The app normally opens and connects automatically. If it does not, tap Connect → USB wired connection.'**
  String get tutorialUsbStep3;

  /// No description provided for @tutorialTroubleshootingTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick checks'**
  String get tutorialTroubleshootingTitle;

  /// No description provided for @tutorialTroubleshootingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check these items before retrying'**
  String get tutorialTroubleshootingSubtitle;

  /// No description provided for @tutorialTroubleshootingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Camera not found: make sure the camera shows its name, is waiting for pairing, and is on the same Wi-Fi or phone hotspot.'**
  String get tutorialTroubleshootingNotFound;

  /// No description provided for @tutorialTroubleshootingManualIp.
  ///
  /// In en, this message translates to:
  /// **'Manual IP only skips automatic discovery. The camera must still remain on the waiting-for-pairing screen.'**
  String get tutorialTroubleshootingManualIp;

  /// No description provided for @tutorialTroubleshootingPairing.
  ///
  /// In en, this message translates to:
  /// **'Pairing keeps waiting: submit the code in the app first, then press OK on the camera without leaving Connect to computer.'**
  String get tutorialTroubleshootingPairing;

  /// No description provided for @tutorialSourceNote.
  ///
  /// In en, this message translates to:
  /// **'Nikon Z menu names can vary by model and firmware. The reliable checkpoint is a camera screen that shows the camera name and says it is waiting for pairing.'**
  String get tutorialSourceNote;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
