// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'ZTransfer';

  @override
  String get appTagline => '尼康 Z 系列 — USB 联机拍摄';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutVersion => '版本';

  @override
  String get aboutAuthor => '作者';

  @override
  String get aboutPlatform => '平台';

  @override
  String get aboutPlatformValue => 'Android · PTP / MTP';

  @override
  String get aboutBuiltWith => '基于 Flutter 构建';

  @override
  String get photos => '照片';

  @override
  String get noProjectSelected => '未选择项目';

  @override
  String get activeProject => '使用中';

  @override
  String get cameraConnected => '已连接';

  @override
  String get cameraConnecting => '连接中…';

  @override
  String get cameraError => '连接失败';

  @override
  String get cameraNoCamera => '未连接相机';

  @override
  String get cameraReady => '就绪 — 可拍摄';

  @override
  String get cameraEstablishing => '正在建立 PTP 会话';

  @override
  String get cameraUnknownError => '未知错误';

  @override
  String get cameraConnectPrompt => '通过 USB 连接尼康 Z 相机';

  @override
  String get cameraConnectFailed => '连接相机失败';

  @override
  String get connect => '连接';

  @override
  String get retry => '重试';

  @override
  String get emptyNoPhotos => '暂无照片 — 请拍摄';

  @override
  String get emptyConnectPrompt => '连接相机以开始使用';

  @override
  String get emptyNoSyncedPhotos => '暂无已同步的照片';

  @override
  String get rawBadge => 'RAW';

  @override
  String get syncing => '同步中…';

  @override
  String get syncError => '同步错误';

  @override
  String lastSync(String fileName) {
    return '上次同步 — $fileName';
  }

  @override
  String get syncNoProjectError => '未选择活动项目，请先创建一个。';

  @override
  String get autoShowOn => '新照片自动全屏 · 已开启';

  @override
  String get autoShowOff => '新照片自动全屏 · 已关闭';

  @override
  String get phoneGallery => '手机相册';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get deleteAll => '全部删除';

  @override
  String selectedCount(int count) {
    return '已选择 $count 张';
  }

  @override
  String deleteConfirmTitle(int count) {
    return '删除 $count 张照片？';
  }

  @override
  String get deleteConfirmMessage => '此操作无法撤销。';

  @override
  String get deleteProjectConfirm => '删除此项目及其所有照片？\n\n此操作无法撤销。';

  @override
  String get projects => '项目';

  @override
  String get newProject => '新建项目';

  @override
  String get projectNameHint => '项目名称';

  @override
  String get create => '创建';

  @override
  String get rename => '重命名';

  @override
  String get renameProject => '重命名项目';

  @override
  String get noProjectsYet => '暂无项目';

  @override
  String get createProjectPrompt => '创建项目以开始整理照片';

  @override
  String get createProject => '创建项目';

  @override
  String deleteProjectTitle(String name) {
    return '删除 \"$name\"？';
  }

  @override
  String photoCount(int count) {
    return '$count 张照片';
  }

  @override
  String get exifIso => 'ISO';

  @override
  String get exifShutter => '快门';

  @override
  String get exifAperture => '光圈';

  @override
  String get exifFocal => '焦距';

  @override
  String get exifBody => '机身';

  @override
  String get exifDate => '日期';

  @override
  String get exifShutterSuffix => '秒';

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
  String get unknown => '未知';

  @override
  String get receivePhotos => '接收';

  @override
  String get stopReceiving => '停止';

  @override
  String get scanNetworkCamera => '扫描网络中的相机';

  @override
  String get scanNetworkCameraInProgress => '正在扫描网络...';

  @override
  String get scanCurrentNetworkStatus => '正在扫描当前 Wi-Fi 与热点网段...';

  @override
  String get scanNotFoundHint => '未发现相机，请确认相机已开启「连接到计算机」且与手机处于同一网络';

  @override
  String get scanTimeoutHint => '扫描超时，请确认网络后重试，或手动输入相机 IP';

  @override
  String scanFailed(String error) {
    return '扫描失败：$error';
  }

  @override
  String get pairingWaitingCameraTitle => '等待相机确认';

  @override
  String get pairingRequestTitle => '相机请求配对';

  @override
  String get pairingRequestSubmittedTitle => '配对请求已提交';

  @override
  String get pairingBeforeSubmitInstructions =>
      '请确认相机屏幕上的配对码与上方一致。\n先点击下方按钮提交配对码，然后再在相机端按 OK。';

  @override
  String get pairingAfterSubmitInstructions =>
      '配对请求已发送。\n现在请在相机端按 OK，App 将继续等待确认。';

  @override
  String get pairingSubmitCode => '提交配对码';

  @override
  String get pairingWaitingCameraConfirmation => '等待相机端按 OK';

  @override
  String get pairingFailed => '配对失败';

  @override
  String get pairingReconnectingStatus => '配对成功，正在重新连接相机...';

  @override
  String pairingConfirmException(String error) {
    return '确认异常：$error';
  }

  @override
  String get transferListeningStarted => '已开始监听，请在相机上选择发送到计算机';

  @override
  String get transferAlreadyListening => '无线图片监听已在运行';

  @override
  String get transferListeningStopped => '无线图片监听已停止';

  @override
  String get transferNotConnected => '请先连接已配对的相机';

  @override
  String get transferListeningActive => '正在监听相机传输';

  @override
  String get transferWaitingForCamera => '等待相机发送照片';

  @override
  String transferReceivingProgress(int progress) {
    return '正在接收照片 · $progress%';
  }

  @override
  String transferRate(String rate) {
    return '速率 $rate';
  }

  @override
  String transferLastRate(String rate) {
    return '上次 $rate';
  }

  @override
  String get tutorialTitle => '使用教程';

  @override
  String get wirelessTutorialLink => '无线连接教程';

  @override
  String get tutorialHeroTitle => '开始前先完成两件事';

  @override
  String get tutorialHeroBody =>
      '先创建或选择一个项目，用于保存接收的照片；无线连接时，先让相机进入“等待配对”页面，再在 App 中扫描。';

  @override
  String get tutorialWirelessTitle => 'Wi-Fi 无线连接';

  @override
  String get tutorialWirelessSubtitle => '首次连接需要配对；已保存的相机以后可直接重连。';

  @override
  String get tutorialChooseCameraType => '按相机中显示的菜单选择类型';

  @override
  String get tutorialModernType => '有“连接类型”';

  @override
  String get tutorialClassicType => '无“连接类型”';

  @override
  String get tutorialModernModels =>
      '示例：ZR / Z9 / Z8 / Z6III / Zf / Z5II / Z50II 等';

  @override
  String get tutorialClassicModels =>
      '示例：Z6 / Z7 / Z6II / Z7II / Z5 / Z50 / Zfc / Z30 等';

  @override
  String get tutorialCameraTypeHint =>
      '不确定时，打开“连接到计算机”：能看到“连接类型”就选第一类，没有该选项就选第二类。';

  @override
  String get tutorialMenuPath => '相机菜单路径';

  @override
  String get tutorialModernMenuPath =>
      'MENU → 网络菜单 → 连接到计算机 → 连接类型 → 图像传送 → 网络设定';

  @override
  String get tutorialClassicMenuPath =>
      'MENU → 设定菜单（扳手）→ 连接到 PC / 连接到计算机 → 网络设定';

  @override
  String get tutorialModernStep1 => '按 MENU 键进入“网络菜单”，选择“连接到计算机”。';

  @override
  String get tutorialModernStep2 => '进入“连接类型”，务必选择“图像传送”，不要选择“相机控制”。';

  @override
  String get tutorialModernStep3 => '进入“网络设定”，新建配置或选择已有配置。';

  @override
  String get tutorialModernStep4 => '让相机连接与手机相同的 Wi-Fi；使用手机热点时，让相机连接该热点。';

  @override
  String get tutorialModernStep5 => 'IP 地址建议选择“自动获得 / 自动获取”，然后继续配对。';

  @override
  String get tutorialModernStep6 =>
      '等相机屏幕显示相机名称并进入等待配对页面，再回到 App 点击“扫描网络中的相机”。';

  @override
  String get tutorialClassicStep1 =>
      '按 MENU 键进入“设定菜单（扳手）”，选择“连接到 PC / 连接到计算机”。';

  @override
  String get tutorialClassicStep2 => '进入“网络设定”，新建配置或选择已有配置。';

  @override
  String get tutorialClassicStep3 => '让相机连接与手机相同的 Wi-Fi；使用手机热点时，让相机连接该热点。';

  @override
  String get tutorialClassicStep4 => 'IP 地址建议选择“自动获得 / 自动获取”，然后继续配对。';

  @override
  String get tutorialClassicStep5 =>
      '等相机屏幕显示相机名称并进入等待配对页面，再回到 App 点击“扫描网络中的相机”。';

  @override
  String get tutorialRequiredScreenTitle => '必须先看到这个相机页面';

  @override
  String get tutorialModernRequiredScreen =>
      '“连接类型”已设为“图像传送”，相机屏幕显示相机名称，并提示正在等待配对。';

  @override
  String get tutorialClassicRequiredScreen => '相机屏幕显示相机名称，并提示正在等待计算机端开始配对。';

  @override
  String get tutorialPairingTitle => '四位码配对顺序';

  @override
  String get tutorialPairingSubtitle => '首次连接时请严格按此顺序操作';

  @override
  String get tutorialPairingStep1 => '在扫描结果中选择相机，等待 App 显示四位配对码。';

  @override
  String get tutorialPairingStep2 => '确认 App 与相机显示的四位码一致。';

  @override
  String get tutorialPairingStep3 => '先在 App 中点击“提交配对码”。';

  @override
  String get tutorialPairingStep4 => '看到“等待相机确认”后，再在相机端按 OK（部分机型为 J/OK）。';

  @override
  String get tutorialPairingStep5 => '保持相机停留在“连接到计算机”页面，直到连接弹窗自动关闭并显示已连接。';

  @override
  String get tutorialReceivingTitle => '接收照片';

  @override
  String get tutorialReceivingSubtitle => '相机连接与照片监听是两个独立状态';

  @override
  String get tutorialReceivingStep1 => '创建或选择一个活动项目，接收到的照片会保存到该项目。';

  @override
  String get tutorialReceivingStep2 => '相机连接成功后点击“接收”，等待页面出现醒目的监听标志。';

  @override
  String get tutorialReceivingStep3 =>
      '在相机回放界面选择照片，并执行“发送到计算机”；具体菜单名称可能因机型不同而略有差异。';

  @override
  String get tutorialReceivingStep4 => '“停止”只结束照片监听，不会断开相机；需要结束连接时再使用“断开连接”。';

  @override
  String get tutorialUsbTitle => 'USB 有线连接';

  @override
  String get tutorialUsbSubtitle => '使用支持 OTG 和数据传输的线缆，可获得最直接的连接';

  @override
  String get tutorialUsbStep1 => '使用支持 OTG 和数据传输的线缆连接尼康相机与手机。';

  @override
  String get tutorialUsbStep2 => '解锁手机；Android 询问时，允许 ZTransfer 访问 USB 设备。';

  @override
  String get tutorialUsbStep3 => 'App 通常会自动唤起并连接；若没有，请点击“连接”→“USB 有线连接”。';

  @override
  String get tutorialTroubleshootingTitle => '快速排查';

  @override
  String get tutorialTroubleshootingSubtitle => '重试前先检查这些条件';

  @override
  String get tutorialTroubleshootingNotFound =>
      '扫描不到相机：确认相机已显示相机名称、处于等待配对状态，并与手机连接同一 Wi-Fi 或手机热点。';

  @override
  String get tutorialTroubleshootingManualIp =>
      '手动 IP 只会跳过自动搜索，不能跳过配对；相机仍需停留在等待配对页面。';

  @override
  String get tutorialTroubleshootingPairing =>
      '配对一直等待：先在 App 提交配对码，再在相机按 OK，并且不要退出“连接到计算机”页面。';

  @override
  String get tutorialSourceNote =>
      '不同 Nikon Z 机型和固件的菜单名称可能略有差异；可靠的判断标准是相机屏幕已经显示相机名称，并提示正在等待配对。';
}
