import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ztransfer/features/gallery/data/models/photo_item.dart';
import 'package:ztransfer/features/gallery/presentation/screens/home_screen.dart';
import 'package:ztransfer/features/gallery/presentation/screens/image_detail_screen.dart';
import 'package:ztransfer/features/gallery/presentation/screens/phone_gallery_screen.dart';
import 'package:ztransfer/features/project/presentation/project_list_screen.dart';
import 'package:ztransfer/features/about/presentation/about_screen.dart';
import 'package:ztransfer/features/tutorial/presentation/tutorial_screen.dart';

// ── Route paths ──────────────────────────────────────────────────────────────

abstract class AppRoute {
  static const home = '/';
  static const projects = '/projects';
  static const phoneGallery = '/phone';
  static const about = '/about';
  static const tutorial = '/tutorial';
  static const imageDetail = '/detail/:objectHandle';

  static String detailPath(int objectHandle) => '/detail/$objectHandle';
}

// ── Shared transitions ───────────────────────────────────────────────────────

/// Slide + fade transition for standard page navigation.
Page<dynamic> _buildPage(Widget child) {
  return CustomTransitionPage<dynamic>(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

// ── Router instance ──────────────────────────────────────────────────────────

final appRouter = GoRouter(
  initialLocation: AppRoute.home,
  routes: [
    GoRoute(
      path: AppRoute.home,
      name: 'home',
      pageBuilder: (context, state) => _buildPage(const HomeScreen()),
    ),
    GoRoute(
      path: AppRoute.projects,
      name: 'projects',
      pageBuilder: (context, state) => _buildPage(const ProjectListScreen()),
    ),
    GoRoute(
      path: AppRoute.phoneGallery,
      name: 'phoneGallery',
      pageBuilder: (context, state) => _buildPage(const PhoneGalleryScreen()),
    ),
    GoRoute(
      path: AppRoute.about,
      name: 'about',
      pageBuilder: (context, state) => _buildPage(const AboutScreen()),
    ),
    GoRoute(
      path: AppRoute.tutorial,
      name: 'tutorial',
      pageBuilder: (context, state) => _buildPage(const TutorialScreen()),
    ),
    GoRoute(
      path: AppRoute.imageDetail,
      name: 'imageDetail',
      pageBuilder: (context, state) {
        final photos = state.extra as List<PhotoItem>? ?? [];
        final index = photos.indexWhere(
          (p) =>
              p.objectHandle.toString() == state.pathParameters['objectHandle'],
        );
        return CustomTransitionPage<dynamic>(
          child: ImageDetailScreen(
            photos: photos,
            initialIndex: index >= 0 ? index : 0,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
      },
    ),
  ],
);
