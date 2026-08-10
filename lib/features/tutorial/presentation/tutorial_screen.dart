import 'package:flutter/material.dart';
import 'package:ztransfer/core/theme/app_colors.dart';
import 'package:ztransfer/l10n/generated/app_localizations.dart';

enum _CameraMenuType { modern, classic }

/// In-app usage guide. Wireless setup mirrors the two Nikon menu families
/// exposed by the current camera pairing flow.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  _CameraMenuType _cameraMenuType = _CameraMenuType.modern;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.tutorialTitle)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720 ? 32.0 : 16.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                32,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 840),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _IntroCard(
                          title: l10n.tutorialHeroTitle,
                          body: l10n.tutorialHeroBody,
                        ),
                        const SizedBox(height: 16),
                        _buildWirelessGuide(l10n),
                        const SizedBox(height: 16),
                        _GuideCard(
                          icon: Icons.pin_rounded,
                          title: l10n.tutorialPairingTitle,
                          subtitle: l10n.tutorialPairingSubtitle,
                          children: _steps([
                            l10n.tutorialPairingStep1,
                            l10n.tutorialPairingStep2,
                            l10n.tutorialPairingStep3,
                            l10n.tutorialPairingStep4,
                            l10n.tutorialPairingStep5,
                          ]),
                        ),
                        const SizedBox(height: 16),
                        _GuideCard(
                          icon: Icons.download_for_offline_outlined,
                          title: l10n.tutorialReceivingTitle,
                          subtitle: l10n.tutorialReceivingSubtitle,
                          children: _steps([
                            l10n.tutorialReceivingStep1,
                            l10n.tutorialReceivingStep2,
                            l10n.tutorialReceivingStep3,
                            l10n.tutorialReceivingStep4,
                          ]),
                        ),
                        const SizedBox(height: 16),
                        _GuideCard(
                          icon: Icons.usb_rounded,
                          title: l10n.tutorialUsbTitle,
                          subtitle: l10n.tutorialUsbSubtitle,
                          children: _steps([
                            l10n.tutorialUsbStep1,
                            l10n.tutorialUsbStep2,
                            l10n.tutorialUsbStep3,
                          ]),
                        ),
                        const SizedBox(height: 16),
                        _TroubleshootingCard(l10n: l10n),
                        const SizedBox(height: 16),
                        _SourceNote(text: l10n.tutorialSourceNote),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWirelessGuide(AppLocalizations l10n) {
    final modern = _cameraMenuType == _CameraMenuType.modern;
    final steps = modern
        ? [
            l10n.tutorialModernStep1,
            l10n.tutorialModernStep2,
            l10n.tutorialModernStep3,
            l10n.tutorialModernStep4,
            l10n.tutorialModernStep5,
            l10n.tutorialModernStep6,
          ]
        : [
            l10n.tutorialClassicStep1,
            l10n.tutorialClassicStep2,
            l10n.tutorialClassicStep3,
            l10n.tutorialClassicStep4,
            l10n.tutorialClassicStep5,
          ];

    return _GuideCard(
      icon: Icons.wifi_rounded,
      title: l10n.tutorialWirelessTitle,
      subtitle: l10n.tutorialWirelessSubtitle,
      children: [
        Text(
          l10n.tutorialChooseCameraType,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CameraTypeChip(
              label: l10n.tutorialModernType,
              selected: modern,
              onSelected: () => setState(
                () => _cameraMenuType = _CameraMenuType.modern,
              ),
            ),
            _CameraTypeChip(
              label: l10n.tutorialClassicType,
              selected: !modern,
              onSelected: () => setState(
                () => _cameraMenuType = _CameraMenuType.classic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          modern ? l10n.tutorialModernModels : l10n.tutorialClassicModels,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.tutorialCameraTypeHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 16),
        _MenuPath(
          label: l10n.tutorialMenuPath,
          path: modern
              ? l10n.tutorialModernMenuPath
              : l10n.tutorialClassicMenuPath,
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Column(
            key: ValueKey(_cameraMenuType),
            children: _steps(steps),
          ),
        ),
        const SizedBox(height: 4),
        _RequiredScreenCallout(
          title: l10n.tutorialRequiredScreenTitle,
          body: modern
              ? l10n.tutorialModernRequiredScreen
              : l10n.tutorialClassicRequiredScreen,
        ),
      ],
    );
  }

  List<Widget> _steps(List<String> steps) {
    return [
      for (var index = 0; index < steps.length; index++)
        _NumberedStep(number: index + 1, text: steps[index]),
    ];
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.black),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceHighlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _CameraTypeChip extends StatelessWidget {
  const _CameraTypeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      backgroundColor: AppColors.surfaceHighlight,
      selectedColor: AppColors.accent.withValues(alpha: 0.18),
      side: BorderSide(
        color: selected ? AppColors.accent : AppColors.surfaceHighlight,
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.accent : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

class _MenuPath extends StatelessWidget {
  const _MenuPath({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            path,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredScreenCallout extends StatelessWidget {
  const _RequiredScreenCallout({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TroubleshootingCard extends StatelessWidget {
  const _TroubleshootingCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return _GuideCard(
      icon: Icons.build_circle_outlined,
      title: l10n.tutorialTroubleshootingTitle,
      subtitle: l10n.tutorialTroubleshootingSubtitle,
      children: [
        _HintRow(text: l10n.tutorialTroubleshootingNotFound),
        _HintRow(text: l10n.tutorialTroubleshootingManualIp),
        _HintRow(text: l10n.tutorialTroubleshootingPairing),
      ],
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.textTertiary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
