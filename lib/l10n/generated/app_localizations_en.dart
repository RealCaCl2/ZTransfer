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
  String get autoShowOn => 'Auto-fullscreen new photos · On';

  @override
  String get autoShowOff => 'Auto-fullscreen new photos · Off';

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
  String get deleteProjectConfirm =>
      'Delete this project and all its photos?\n\nThis cannot be undone.';

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
  String get createProjectPrompt =>
      'Create a project to start organizing your photos';

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

  @override
  String get receivePhotos => 'Receive';

  @override
  String get stopReceiving => 'Stop';

  @override
  String get scanNetworkCamera => 'Scan for cameras';

  @override
  String get scanNetworkCameraInProgress => 'Scanning network...';

  @override
  String get scanCurrentNetworkStatus =>
      'Scanning the current Wi-Fi and hotspot networks...';

  @override
  String get scanNotFoundHint =>
      'No camera found. Make sure Connect to computer is enabled and the camera is on the same network.';

  @override
  String get scanTimeoutHint =>
      'Scan timed out. Check the network and retry, or enter the camera IP manually.';

  @override
  String scanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get pairingWaitingCameraTitle => 'Waiting for camera';

  @override
  String get pairingRequestTitle => 'Camera pairing request';

  @override
  String get pairingRequestSubmittedTitle => 'Pairing request submitted';

  @override
  String get pairingBeforeSubmitInstructions =>
      'Make sure the pairing code on the camera matches the code above.\nSubmit the code below first, then press OK on the camera.';

  @override
  String get pairingAfterSubmitInstructions =>
      'The pairing request has been sent.\nNow press OK on the camera while the app waits for confirmation.';

  @override
  String get pairingSubmitCode => 'Submit pairing code';

  @override
  String get pairingWaitingCameraConfirmation => 'Waiting for camera OK';

  @override
  String get pairingFailed => 'Pairing failed';

  @override
  String get pairingReconnectingStatus =>
      'Pairing succeeded. Reconnecting to the camera...';

  @override
  String pairingConfirmException(String error) {
    return 'Confirmation failed: $error';
  }

  @override
  String get transferListeningStarted =>
      'Listening for photos selected on the camera';

  @override
  String get transferAlreadyListening => 'Photo receiving is already active';

  @override
  String get transferListeningStopped => 'Photo receiving stopped';

  @override
  String get transferNotConnected =>
      'Connect a paired camera before receiving photos';

  @override
  String get transferListeningActive => 'LISTENING FOR CAMERA';

  @override
  String get transferWaitingForCamera =>
      'Waiting for a photo selected on the camera';

  @override
  String transferReceivingProgress(int progress) {
    return 'Receiving photo · $progress%';
  }

  @override
  String transferRate(String rate) {
    return 'Speed $rate';
  }

  @override
  String transferLastRate(String rate) {
    return 'Last $rate';
  }

  @override
  String get tutorialTitle => 'User Guide';

  @override
  String get wirelessTutorialLink => 'Wireless connection guide';

  @override
  String get tutorialHeroTitle => 'Two things before you start';

  @override
  String get tutorialHeroBody =>
      'Create or select a project to store received photos. For Wi-Fi, put the camera on its waiting-for-pairing screen before scanning in the app.';

  @override
  String get tutorialWirelessTitle => 'Wi-Fi connection';

  @override
  String get tutorialWirelessSubtitle =>
      'The first connection requires pairing. Saved cameras can reconnect directly later.';

  @override
  String get tutorialChooseCameraType =>
      'Choose the menu type shown by your camera';

  @override
  String get tutorialModernType => 'Has Connection type';

  @override
  String get tutorialClassicType => 'No Connection type';

  @override
  String get tutorialModernModels =>
      'Examples: ZR / Z9 / Z8 / Z6III / Zf / Z5II / Z50II';

  @override
  String get tutorialClassicModels =>
      'Examples: Z6 / Z7 / Z6II / Z7II / Z5 / Z50 / Zfc / Z30';

  @override
  String get tutorialCameraTypeHint =>
      'Not sure? Open Connect to computer. Choose the first option if Connection type is present; otherwise choose the second.';

  @override
  String get tutorialMenuPath => 'CAMERA MENU PATH';

  @override
  String get tutorialModernMenuPath =>
      'MENU → Network menu → Connect to computer → Connection type → Image transfer → Network settings';

  @override
  String get tutorialClassicMenuPath =>
      'MENU → Setup menu (wrench) → Connect to PC / Connect to computer → Network settings';

  @override
  String get tutorialModernStep1 =>
      'Press MENU, open Network menu, then select Connect to computer.';

  @override
  String get tutorialModernStep2 =>
      'Open Connection type and select Image transfer. Do not select Camera control.';

  @override
  String get tutorialModernStep3 =>
      'Open Network settings, then create a new profile or select an existing one.';

  @override
  String get tutorialModernStep4 =>
      'Connect the camera to the same Wi-Fi as the phone, or connect it to the phone hotspot.';

  @override
  String get tutorialModernStep5 =>
      'Use Obtain automatically / Auto for the IP address, then continue pairing.';

  @override
  String get tutorialModernStep6 =>
      'Wait until the camera shows its name and enters the pairing screen, then return to the app and tap Scan for cameras.';

  @override
  String get tutorialClassicStep1 =>
      'Press MENU, open Setup menu (wrench), then select Connect to PC / Connect to computer.';

  @override
  String get tutorialClassicStep2 =>
      'Open Network settings, then create a new profile or select an existing one.';

  @override
  String get tutorialClassicStep3 =>
      'Connect the camera to the same Wi-Fi as the phone, or connect it to the phone hotspot.';

  @override
  String get tutorialClassicStep4 =>
      'Use Obtain automatically / Auto for the IP address, then continue pairing.';

  @override
  String get tutorialClassicStep5 =>
      'Wait until the camera shows its name and enters the pairing screen, then return to the app and tap Scan for cameras.';

  @override
  String get tutorialRequiredScreenTitle => 'The camera must reach this screen';

  @override
  String get tutorialModernRequiredScreen =>
      'Connection type is set to Image transfer, and the camera screen shows the camera name with a waiting-for-pairing message.';

  @override
  String get tutorialClassicRequiredScreen =>
      'The camera screen shows the camera name and indicates that it is waiting for the computer to start pairing.';

  @override
  String get tutorialPairingTitle => 'Pairing code sequence';

  @override
  String get tutorialPairingSubtitle =>
      'Follow this order during the first connection';

  @override
  String get tutorialPairingStep1 =>
      'Select the camera in the scan results and wait for the app to show a four-digit pairing code.';

  @override
  String get tutorialPairingStep2 =>
      'Confirm that the four-digit codes shown by the app and camera match.';

  @override
  String get tutorialPairingStep3 =>
      'Tap Submit pairing code in the app first.';

  @override
  String get tutorialPairingStep4 =>
      'After Waiting for camera appears, press OK on the camera (J/OK on some models).';

  @override
  String get tutorialPairingStep5 =>
      'Keep the camera on Connect to computer until the dialog closes automatically and the app shows Connected.';

  @override
  String get tutorialReceivingTitle => 'Receive photos';

  @override
  String get tutorialReceivingSubtitle =>
      'The camera connection and the receiving listener are separate states';

  @override
  String get tutorialReceivingStep1 =>
      'Create or select an active project. Received photos are saved into that project.';

  @override
  String get tutorialReceivingStep2 =>
      'After the camera connects, tap Receive and wait for the prominent listening indicator.';

  @override
  String get tutorialReceivingStep3 =>
      'On the camera playback screen, select photos and choose Send to computer. The exact menu wording may differ by model.';

  @override
  String get tutorialReceivingStep4 =>
      'Stop ends photo listening only and keeps the camera connected. Use Disconnect when you want to end the connection.';

  @override
  String get tutorialUsbTitle => 'USB connection';

  @override
  String get tutorialUsbSubtitle =>
      'Use an OTG-capable data cable for the most direct connection';

  @override
  String get tutorialUsbStep1 =>
      'Connect the Nikon camera to the phone with an OTG-capable data cable.';

  @override
  String get tutorialUsbStep2 =>
      'Unlock the phone and allow ZTransfer to access the USB device when Android asks.';

  @override
  String get tutorialUsbStep3 =>
      'The app normally opens and connects automatically. If it does not, tap Connect → USB wired connection.';

  @override
  String get tutorialTroubleshootingTitle => 'Quick checks';

  @override
  String get tutorialTroubleshootingSubtitle =>
      'Check these items before retrying';

  @override
  String get tutorialTroubleshootingNotFound =>
      'Camera not found: make sure the camera shows its name, is waiting for pairing, and is on the same Wi-Fi or phone hotspot.';

  @override
  String get tutorialTroubleshootingManualIp =>
      'Manual IP only skips automatic discovery. The camera must still remain on the waiting-for-pairing screen.';

  @override
  String get tutorialTroubleshootingPairing =>
      'Pairing keeps waiting: submit the code in the app first, then press OK on the camera without leaving Connect to computer.';

  @override
  String get tutorialSourceNote =>
      'Nikon Z menu names can vary by model and firmware. The reliable checkpoint is a camera screen that shows the camera name and says it is waiting for pairing.';
}
