import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_mode_selection.dart';

class SnakeHomePage extends StatelessWidget {
  final User user;
  const SnakeHomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GameModeSelectionScreen(user: user),
        ),
      );
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _SnakeBlock extends StatelessWidget {
  final double size;
  const _SnakeBlock({this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF7ED957),
        borderRadius: BorderRadius.circular(size / 4),
      ),
    );
  }
}

class _SnakeHead extends StatelessWidget {
  final double size;
  const _SnakeHead({this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF7ED957),
            borderRadius: BorderRadius.circular(size / 3),
          ),
        ),
        Positioned(
          right: size * 0.2,
          top: size * 0.3,
          child: Container(
            width: size * 0.25,
            height: size * 0.25,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: size * 0.12,
                height: size * 0.12,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Apple extends StatelessWidget {
  final double size;
  const _Apple({this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF7ED957),
            shape: BoxShape.circle,
          ),
        ),
        Positioned(
          top: size * 0.08,
          left: size * 0.7,
          child: Container(
            width: size * 0.25,
            height: size * 0.25,
            decoration: const BoxDecoration(
              color: Color(0xFF23272A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
                bottomLeft: Radius.circular(2),
                bottomRight: Radius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  const _CircleIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF23272A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}
