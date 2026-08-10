import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ztransfer/app_router.dart';
import 'package:ztransfer/core/theme/app_colors.dart';
import 'package:ztransfer/l10n/generated/app_localizations.dart';
import 'package:ztransfer/features/project/data/models/project.dart';
import 'package:ztransfer/features/project/presentation/project_notifier.dart';

/// Full project list screen with create/edit/delete/select.
class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh project metadata (photo counts, covers) on every visit
    Future.microtask(() {
      ref.read(projectNotifierProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectNotifierProvider);
    final projects = state.projects;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.projects),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.accent),
            onPressed: () => _showCreateDialog(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_open_outlined,
                          size: 64, color: AppColors.textTertiary),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.noProjectsYet,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(AppLocalizations.of(context)!.createProjectPrompt,
                          style: const TextStyle(
                              color: AppColors.textTertiary, fontSize: 13)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateDialog(),
                        icon: const Icon(Icons.add),
                        label: Text(AppLocalizations.of(context)!.createProject),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final isActive =
                        state.activeProject?.id == project.id;
                    return _ProjectCard(
                      project: project,
                      isActive: isActive,
                      onTap: () async {
                        await ref
                            .read(projectNotifierProvider.notifier)
                            .setActiveProject(project.id);
                        if (context.mounted) {
                          context.go(AppRoute.home);
                        }
                      },
                      onRename: () =>
                          _showRenameDialog(project),
                      onDelete: () =>
                          _showDeleteDialog(project),
                    );
                  },
                ),
    );
  }

  void _showCreateDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.newProject),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.projectNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(AppLocalizations.of(context)!.create)),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(projectNotifierProvider.notifier).createProject(name);
      ref.read(projectNotifierProvider.notifier).refresh();
    }
  }

  void _showRenameDialog(Project project) async {
    final ctrl = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.renameProject),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(AppLocalizations.of(context)!.rename)),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      ref
          .read(projectNotifierProvider.notifier)
          .updateProject(project.id, name);
    }
  }

  void _showDeleteDialog(Project project) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteProjectTitle(project.name)),
        content: Text(AppLocalizations.of(context)!.deleteProjectConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context)!.deleteAll,
                  style: const TextStyle(color: AppColors.statusError))),
        ],
      ),
    );
    if (result == true) {
      ref
          .read(projectNotifierProvider.notifier)
          .deleteProject(project.id, true);
    }
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isActive ? AppColors.surfaceHighlight : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? const BorderSide(color: AppColors.accent, width: 1.5)
            : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Cover thumbnail
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: project.coverPhotoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(project.coverPhotoPath!),
                          fit: BoxFit.cover,
                          cacheWidth: 128,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.folder,
                              color: AppColors.accent,
                              size: 28),
                        ),
                      )
                    : const Icon(Icons.folder,
                        color: AppColors.accent, size: 28),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(project.name,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(AppLocalizations.of(context)!.activeProject,
                                style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${AppLocalizations.of(context)!.photoCount(project.photoCount)} · ${project.formattedDate}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    color: AppColors.textSecondary, size: 20),
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                      value: 'rename',
                      child: Text(AppLocalizations.of(context)!.rename)),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text(AppLocalizations.of(context)!.delete,
                          style:
                              const TextStyle(color: AppColors.statusError))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
