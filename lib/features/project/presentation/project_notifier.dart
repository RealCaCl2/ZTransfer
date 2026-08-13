import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ztransfer/core/logger/app_logger.dart';
import 'package:ztransfer/features/camera/data/camera_repository.dart';
import 'package:ztransfer/features/project/data/models/project.dart';

/// Observable state for the project management system.
class ProjectState {
  final List<Project> projects;
  final Project? activeProject;
  final bool isLoading;
  final String? error;

  const ProjectState({
    this.projects = const [],
    this.activeProject,
    this.isLoading = false,
    this.error,
  });

  ProjectState copyWith({
    List<Project>? projects,
    Project? activeProject,
    bool clearActiveProject = false,
    bool? isLoading,
    String? error,
  }) {
    return ProjectState(
      projects: projects ?? this.projects,
      activeProject:
          clearActiveProject ? null : activeProject ?? this.activeProject,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProjectNotifier extends StateNotifier<ProjectState> {
  final CameraRepository _repo;

  ProjectNotifier(this._repo) : super(const ProjectState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      await _loadProjects();
      await _loadActiveProject();
    } catch (e, st) {
      appLogger.e('ProjectNotifier init failed', error: e, stackTrace: st);
      state = state.copyWith(error: '$e');
    }
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadProjects() async {
    try {
      final raw = await _repo.listProjects();
      state = state.copyWith(projects: raw.map(Project.fromMap).toList());
    } catch (e, st) {
      appLogger.e('_loadProjects failed', error: e, stackTrace: st);
      // Keep existing projects list — don't clear on error
    }
  }

  Future<void> _loadActiveProject() async {
    final raw = await _repo.getActiveProject();
    if (raw != null) {
      state = state.copyWith(activeProject: Project.fromMap(raw));
    } else if (state.projects.isNotEmpty) {
      // Auto-select first project
      await setActiveProject(state.projects.first.id);
    } else {
      state = state.copyWith(clearActiveProject: true);
    }
  }

  Future<Project?> createProject(String name) async {
    final raw = await _repo.createProject(name);
    if (raw != null) {
      final project = Project.fromMap(raw);
      state = state.copyWith(projects: [project, ...state.projects]);
      // Auto-activate if no active project
      if (state.activeProject == null) {
        await setActiveProject(project.id);
      }
      return project;
    }
    return null;
  }

  Future<bool> updateProject(String id, String name) async {
    final ok = await _repo.updateProject(id, name);
    if (ok) await _loadProjects();
    return ok;
  }

  Future<bool> deleteProject(String id, bool deletePhotos) async {
    final ok = await _repo.deleteProject(id, deletePhotos);
    if (ok) {
      await _loadProjects();
      // If active project was deleted, switch
      if (state.activeProject?.id == id) {
        if (state.projects.isNotEmpty) {
          await setActiveProject(state.projects.first.id);
        } else {
          state = state.copyWith(clearActiveProject: true);
        }
      }
    }
    return ok;
  }

  Future<void> setActiveProject(String id) async {
    await _repo.setActiveProject(id);
    final raw = await _repo.getActiveProject();
    if (raw != null) {
      state = state.copyWith(activeProject: Project.fromMap(raw));
    }
  }

  Future<void> refresh() async {
    await _loadProjects();
    await _loadActiveProject();
  }

  bool get hasProjects => state.projects.isNotEmpty;
  bool get hasActiveProject => state.activeProject != null;
}

final projectNotifierProvider =
    StateNotifierProvider<ProjectNotifier, ProjectState>((ref) {
  return ProjectNotifier(CameraRepository());
});
