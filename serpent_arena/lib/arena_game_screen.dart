import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ArenaGameScreen extends StatefulWidget {
  final User user;
  const ArenaGameScreen({super.key, required this.user});

  @override
  State<ArenaGameScreen> createState() => _ArenaGameScreenState();
}

class _ArenaGameScreenState extends State<ArenaGameScreen> {
  static const int rowCount = 30;
  static const int colCount = 30;
  static const double cellSize = 12.0;

  late List<Offset> playerSnake;
  late String playerDirection;
  late int score;
  late bool isGameOver;
  late Offset apple;
  Timer? timer;

  List<List<Offset>> aiSnakes = [];
  List<String> aiDirections = [];
  Random random = Random();
  final FocusNode _focusNode = FocusNode();
  int snakesDefeated = 0;
  int? arenaHighScore;
  int? arenaSnakesDefeated;
  bool directionChanged = false;

  @override
  void initState() {
    super.initState();
    _fetchArenaStats();
    _startGame();
  }

  Future<void> _fetchArenaStats() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .get();
    setState(() {
      arenaHighScore = doc.data()?['arenaHighScore'] ?? 0;
      arenaSnakesDefeated = doc.data()?['arenaSnakesDefeated'] ?? 0;
    });
  }

  void _startGame() {
    playerSnake = [
      const Offset(15, 15),
      const Offset(14, 15),
      const Offset(13, 15),
    ];
    playerDirection = 'right';
    score = 0;
    isGameOver = false;
    aiSnakes = [];
    aiDirections = [];
    snakesDefeated = 0;
    _spawnApple();
    // Spawn 2 AI snakes immediately
    _spawnAiSnake();
    _spawnAiSnake();
    timer?.cancel();
    timer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _gameTick(),
    );
  }

  void _spawnApple() {
    while (true) {
      final pos = Offset(
        random.nextInt(colCount).toDouble(),
        random.nextInt(rowCount).toDouble(),
      );
      if (!playerSnake.contains(pos) &&
          aiSnakes.every((snake) => !snake.contains(pos))) {
        apple = pos;
        break;
      }
    }
  }

  void _spawnAiSnake() {
    // Define the four corners
    final corners = [
      const Offset(0, 0),
      Offset(colCount - 1, 0),
      Offset(0, rowCount - 1),
      Offset(colCount - 1, rowCount - 1),
    ];
    // Shuffle corners for randomness
    final shuffledCorners = List<Offset>.from(corners)..shuffle(random);
    for (final head in shuffledCorners) {
      // Check if corner is free
      if (playerSnake.contains(head) ||
          aiSnakes.any((snake) => snake.contains(head)))
        continue;
      // Try to spawn a 3-block snake horizontally (to the right)
      final snake = [
        head,
        Offset(head.dx + 1, head.dy),
        Offset(head.dx + 2, head.dy),
      ];
      if (snake.any(
        (pos) =>
            pos.dx < 0 ||
            pos.dx >= colCount ||
            pos.dy < 0 ||
            pos.dy >= rowCount ||
            playerSnake.contains(pos) ||
            aiSnakes.any((s) => s.contains(pos)),
      )) {
        continue;
      }
      aiSnakes.add(snake);
      aiDirections.add('right');
      break;
    }
  }

  void _gameTick() {
    if (isGameOver) return;
    // Move player
    _movePlayer();
    // Move AI snakes
    for (int i = 0; i < aiSnakes.length; i++) {
      _moveAiSnake(i);
    }
    // Remove dead AI snakes and award points/defeat count
    int defeatedThisTick = 0;
    for (int i = aiSnakes.length - 1; i >= 0; i--) {
      if (_isAiSnakeDead(i)) {
        aiSnakes.removeAt(i);
        aiDirections.removeAt(i);
        defeatedThisTick++;
      }
    }
    if (defeatedThisTick > 0) {
      score += 5 * defeatedThisTick;
      snakesDefeated += defeatedThisTick;
    }
    // Ensure there are always 2 AI snakes
    while (aiSnakes.length < 2) {
      _spawnAiSnake();
    }
    // Shrink player snake by 25% for each defeated AI snake
    for (int i = 0; i < defeatedThisTick; i++) {
      int shrinkAmount = (playerSnake.length * 0.25).floor();
      if (shrinkAmount < 1) shrinkAmount = 1;
      if (playerSnake.length > shrinkAmount) {
        playerSnake = playerSnake.sublist(0, playerSnake.length - shrinkAmount);
      } else {
        playerSnake = [playerSnake.first];
      }
    }
    directionChanged = false;
    setState(() {});
  }

  void _movePlayer() {
    final head = playerSnake.first;
    Offset newHead;
    switch (playerDirection) {
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
    // Check for wall or self collision
    if (newHead.dx < 0 ||
        newHead.dx >= colCount ||
        newHead.dy < 0 ||
        newHead.dy >= rowCount ||
        playerSnake.contains(newHead)) {
      _endGame();
      return;
    }
    // If player collides with any AI snake, game over
    if (aiSnakes.any((snake) => snake.contains(newHead))) {
      _endGame();
      return;
    }
    playerSnake = [newHead, ...playerSnake];
    if (newHead == apple) {
      score++;
      _spawnApple();
    } else {
      playerSnake.removeLast();
    }
  }

  void _moveAiSnake(int index) {
    final snake = aiSnakes[index];
    final direction = aiDirections[index];
    final head = snake.first;
    // Possible directions
    List<String> possibleDirections = ['up', 'down', 'left', 'right'];
    possibleDirections.remove(_oppositeDirection(direction));
    // Filter out directions that would cause a collision
    possibleDirections =
        possibleDirections.where((dir) {
          Offset newHead;
          switch (dir) {
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
          // Check for wall, self, player, or other AI collision
          if (newHead.dx < 0 ||
              newHead.dx >= colCount ||
              newHead.dy < 0 ||
              newHead.dy >= rowCount)
            return false;
          if (snake.contains(newHead)) return false;
          if (playerSnake.contains(newHead)) return false;
          if (aiSnakes.asMap().entries.any(
            (e) => e.key != index && e.value.contains(newHead),
          ))
            return false;
          return true;
        }).toList();
    if (possibleDirections.isEmpty) {
      // No safe moves, mark as dead
      aiSnakes[index] = [];
      return;
    }
    // Prefer moving toward apple if possible
    String newDirection =
        possibleDirections[random.nextInt(possibleDirections.length)];
    if (random.nextDouble() < 0.5) {
      if (apple.dx > head.dx && possibleDirections.contains('right'))
        newDirection = 'right';
      else if (apple.dx < head.dx && possibleDirections.contains('left'))
        newDirection = 'left';
      else if (apple.dy > head.dy && possibleDirections.contains('down'))
        newDirection = 'down';
      else if (apple.dy < head.dy && possibleDirections.contains('up'))
        newDirection = 'up';
    }
    Offset newHead;
    switch (newDirection) {
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
    // Remove special defeat logic, just mark as dead if collides with player or anything else
    if (playerSnake.isNotEmpty && newHead == playerSnake.first) {
      aiSnakes[index] = [];
      return;
    }
    if (newHead.dx < 0 ||
        newHead.dx >= colCount ||
        newHead.dy < 0 ||
        newHead.dy >= rowCount ||
        snake.contains(newHead) ||
        aiSnakes.asMap().entries.any(
          (e) => e.key != index && e.value.contains(newHead),
        )) {
      aiSnakes[index] = [];
      return;
    }
    aiSnakes[index] = [newHead, ...snake];
    if (newHead == apple) {
      _spawnApple();
    } else {
      aiSnakes[index].removeLast();
    }
    aiDirections[index] = newDirection;
  }

  bool _isAiSnakeDead(int index) {
    return aiSnakes[index].isEmpty;
  }

  String _oppositeDirection(String dir) {
    switch (dir) {
      case 'up':
        return 'down';
      case 'down':
        return 'up';
      case 'left':
        return 'right';
      case 'right':
        return 'left';
      default:
        return '';
    }
  }

  Future<void> _endGame() async {
    setState(() {
      isGameOver = true;
    });
    timer?.cancel();
    // Save arenaHighScore and arenaSnakesDefeated if new best
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid);
    final doc = await userDoc.get();
    final prevHigh = doc.data()?['arenaHighScore'] ?? 0;
    final prevDefeated = doc.data()?['arenaSnakesDefeated'] ?? 0;
    bool newHigh = false;
    bool newDefeated = false;
    if (score > prevHigh) {
      await userDoc.set({'arenaHighScore': score}, SetOptions(merge: true));
      setState(() {
        arenaHighScore = score;
      });
      newHigh = true;
    } else {
      setState(() {
        arenaHighScore = prevHigh;
      });
    }
    if (snakesDefeated > prevDefeated) {
      await userDoc.set({
        'arenaSnakesDefeated': snakesDefeated,
      }, SetOptions(merge: true));
      setState(() {
        arenaSnakesDefeated = snakesDefeated;
      });
      newDefeated = true;
    } else {
      setState(() {
        arenaSnakesDefeated = prevDefeated;
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
              title: const Text(
                'Game Over',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Score: $score',
                    style: const TextStyle(color: Colors.white70, fontSize: 20),
                  ),
                  Text(
                    'Snakes Defeated: $snakesDefeated',
                    style: const TextStyle(color: Colors.orange, fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  if (arenaHighScore != null)
                    Text(
                      'High Score: $arenaHighScore',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 18,
                      ),
                    ),
                  if (arenaSnakesDefeated != null)
                    Text(
                      'Most Snakes Defeated: $arenaSnakesDefeated',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 18,
                      ),
                    ),
                  if (newHigh)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        '🎉 New High Score!',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (newDefeated)
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text(
                        '🎉 New Most Snakes Defeated!',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
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

  void _changePlayerDirection(String newDirection) {
    if (directionChanged) return;
    if ((playerDirection == 'up' && newDirection == 'down') ||
        (playerDirection == 'down' && newDirection == 'up') ||
        (playerDirection == 'left' && newDirection == 'right') ||
        (playerDirection == 'right' && newDirection == 'left')) {
      return;
    }
    setState(() {
      playerDirection = newDirection;
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Arena Mode', style: TextStyle(color: Colors.white)),
            const SizedBox(width: 24),
            Text(
              'Score: $score',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Snakes: $snakesDefeated',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 18),
            ),
          ],
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
              if (key == 'w') _changePlayerDirection('up');
              if (key == 'a') _changePlayerDirection('left');
              if (key == 's') _changePlayerDirection('down');
              if (key == 'd') _changePlayerDirection('right');
            }
          },
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -5) {
                _changePlayerDirection('up');
              } else if (details.primaryDelta! > 5) {
                _changePlayerDirection('down');
              }
            },
            onHorizontalDragUpdate: (details) {
              if (details.primaryDelta! < -5) {
                _changePlayerDirection('left');
              } else if (details.primaryDelta! > 5) {
                _changePlayerDirection('right');
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
                  // Player snake
                  for (int i = 0; i < playerSnake.length; i++)
                    Positioned(
                      left: playerSnake[i].dx * cellSize,
                      top: playerSnake[i].dy * cellSize,
                      child:
                          i == 0
                              ? _SnakeHead(size: cellSize)
                              : _SnakeBlock(size: cellSize),
                    ),
                  // AI snakes
                  for (final snake in aiSnakes)
                    for (int i = 0; i < snake.length; i++)
                      Positioned(
                        left: snake[i].dx * cellSize,
                        top: snake[i].dy * cellSize,
                        child: _AiSnakeBlock(size: cellSize, isHead: i == 0),
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

class _AiSnakeBlock extends StatelessWidget {
  final double size;
  final bool isHead;
  const _AiSnakeBlock({this.size = 28, this.isHead = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isHead ? const Color(0xFFFF9800) : const Color(0xFFFFB74D),
        borderRadius: BorderRadius.circular(size / 4),
        border: isHead ? Border.all(color: Colors.deepOrange, width: 2) : null,
      ),
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
