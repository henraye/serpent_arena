import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';

class GameScreen extends StatefulWidget {
  final User user;
  const GameScreen({super.key, required this.user});

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
  int? highScore;
  Timer? timer;
  final FocusNode _focusNode = FocusNode();
  bool directionChanged = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _fetchHighScore();
    _startGame();
  }

  Future<void> _fetchHighScore() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .get();
    setState(() {
      highScore = doc.data()?['classic']?['highScore'] ?? 0;
    });
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
    _focusNode.requestFocus();
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
      directionChanged = false;
    });
  }

  Future<void> _endGame() async {
    setState(() {
      isGameOver = true;
    });
    timer?.cancel();
    // Check and update high score
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid);
    final doc = await userDoc.get();
    final prevHigh = doc.data()?['classic']?['highScore'] ?? 0;
    bool isNewHigh = false;
    if (score > prevHigh) {
      await userDoc.set({
        'classic': {'highScore': score},
      }, SetOptions(merge: true));
      setState(() {
        highScore = score;
      });
      isNewHigh = true;
    } else {
      setState(() {
        highScore = prevHigh;
      });
    }
    // Show dialog
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              backgroundColor: const Color(0xFF23272A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                isNewHigh ? '🎉 New High Score!' : 'Game Over',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              content: Text(
                isNewHigh
                    ? 'Congratulations! You set a new high score of $score.'
                    : 'Your score: $score\nHigh score: $highScore',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Color(0xFF7ED957), fontSize: 18),
                  ),
                ),
              ],
            ),
      );
    }
  }

  void _changeDirection(String newDirection) {
    if (directionChanged) return;
    // Prevent reversing
    if ((direction == 'up' && newDirection == 'down') ||
        (direction == 'down' && newDirection == 'up') ||
        (direction == 'left' && newDirection == 'right') ||
        (direction == 'right' && newDirection == 'left')) {
      return;
    }
    setState(() {
      direction = newDirection;
      directionChanged = true;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _focusNode.dispose();
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
        child: RawKeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKey: (RawKeyEvent event) {
            if (event is RawKeyDownEvent) {
              final key = event.logicalKey.keyLabel.toLowerCase();
              if (key == 'w') _changeDirection('up');
              if (key == 'a') _changeDirection('left');
              if (key == 's') _changeDirection('down');
              if (key == 'd') _changeDirection('right');
            }
          },
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
              decoration: BoxDecoration(color: const Color(0xFF181A1B)),
              child: Stack(
                children: [
                  // Grid overlay
                  CustomPaint(
                    size: Size(boardWidth, boardHeight),
                    painter: _GridPainter(
                      rowCount: rowCount,
                      colCount: colCount,
                      cellSize: cellSize,
                    ),
                  ),
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
                              if (highScore != null)
                                Text(
                                  'High Score: $highScore',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 20,
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

class _GridPainter extends CustomPainter {
  final int rowCount;
  final int colCount;
  final double cellSize;
  _GridPainter({
    required this.rowCount,
    required this.colCount,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white24
          ..strokeWidth = 0.5;
    // Draw vertical lines
    for (int c = 0; c <= colCount; c++) {
      final x = c * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Draw horizontal lines
    for (int r = 0; r <= rowCount; r++) {
      final y = r * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
