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
  String get autoShowOn => '自动放大: 开';

  @override
  String get autoShowOff => '自动放大: 关';

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
}
