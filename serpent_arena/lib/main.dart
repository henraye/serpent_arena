import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const SnakeApp());
}

class SnakeApp extends StatelessWidget {
  const SnakeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Snake Game',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF23272A),
      ),
      home: const SnakeHomePage(),
    );
  }
}

class SnakeHomePage extends StatelessWidget {
  const SnakeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                'SNAKE',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GameScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7ED957),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'PLAY',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Game area
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF181A1B),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    // Snake body (placeholder)
                    for (int i = 0; i < 5; i++)
                      Positioned(
                        left: 24.0 + i * 28,
                        top: 140,
                        child: _SnakeBlock(size: 28),
                      ),
                    // Snake head (with eye)
                    Positioned(
                      left: 24.0 + 4 * 28,
                      top: 112,
                      child: _SnakeHead(size: 28),
                    ),
                    // Apple
                    Positioned(left: 160, top: 32, child: _Apple(size: 24)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Bottom buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _CircleIcon(icon: Icons.pause),
                  SizedBox(width: 32),
                  _CircleIcon(icon: Icons.volume_up),
                  SizedBox(width: 32),
                  _CircleIcon(icon: Icons.help_outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

// GameScreen where the game takes place
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int rowCount = 20;
  static const int colCount = 20;
  static const double cellSize = 16.0;

  late List<Offset> snake;
  late Offset apple;
  late String direction;
  late int score;
  late bool isGameOver;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    snake = [const Offset(10, 10), const Offset(9, 10), const Offset(8, 10)];
    direction = 'right';
    score = 0;
    isGameOver = false;
    _spawnApple();
    timer?.cancel();
    timer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _moveSnake(),
    );
  }

  void _spawnApple() {
    final random = Random();
    while (true) {
      final pos = Offset(
        random.nextInt(colCount).toDouble(),
        random.nextInt(rowCount).toDouble(),
      );
      if (!snake.contains(pos)) {
        apple = pos;
        break;
      }
    }
  }

  void _moveSnake() {
    if (isGameOver) return;
    final head = snake.first;
    Offset newHead;
    switch (direction) {
      case 'up':
        newHead = Offset(head.dx, head.dy - 1);
        break;
      case 'down':
        newHead = Offset(head.dx, head.dy + 1);
        break;
      case 'left':
        newHead = Offset(head.dx - 1, head.dy);
        break;
      case 'right':
      default:
        newHead = Offset(head.dx + 1, head.dy);
        break;
    }
    // Check for wall collision
    if (newHead.dx < 0 ||
        newHead.dx >= colCount ||
        newHead.dy < 0 ||
        newHead.dy >= rowCount) {
      _endGame();
      return;
    }
    // Check for self collision
    if (snake.contains(newHead)) {
      _endGame();
      return;
    }
    setState(() {
      snake = [newHead, ...snake];
      if (newHead == apple) {
        score++;
        _spawnApple();
      } else {
        snake.removeLast();
      }
    });
  }

  void _endGame() {
    setState(() {
      isGameOver = true;
    });
    timer?.cancel();
  }

  void _changeDirection(String newDirection) {
    // Prevent reversing
    if ((direction == 'up' && newDirection == 'down') ||
        (direction == 'down' && newDirection == 'up') ||
        (direction == 'left' && newDirection == 'right') ||
        (direction == 'right' && newDirection == 'left')) {
      return;
    }
    setState(() {
      direction = newDirection;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardWidth = colCount * cellSize;
    final boardHeight = rowCount * cellSize;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Score: $score',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! < -5) {
              _changeDirection('up');
            } else if (details.primaryDelta! > 5) {
              _changeDirection('down');
            }
          },
          onHorizontalDragUpdate: (details) {
            if (details.primaryDelta! < -5) {
              _changeDirection('left');
            } else if (details.primaryDelta! > 5) {
              _changeDirection('right');
            }
          },
          child: Container(
            width: boardWidth,
            height: boardHeight,
            decoration: BoxDecoration(
              color: const Color(0xFF181A1B),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                // Apple
                Positioned(
                  left: apple.dx * cellSize,
                  top: apple.dy * cellSize,
                  child: _Apple(size: cellSize),
                ),
                // Snake
                for (int i = 0; i < snake.length; i++)
                  Positioned(
                    left: snake[i].dx * cellSize,
                    top: snake[i].dy * cellSize,
                    child:
                        i == 0
                            ? _SnakeHead(size: cellSize)
                            : _SnakeBlock(size: cellSize),
                  ),
                // Game Over overlay
                if (isGameOver)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Game Over',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _startGame,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF7ED957),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text(
                                'Restart',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
