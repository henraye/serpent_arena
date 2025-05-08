import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signInScreen.dart';
import 'main.dart';
import 'package:restart_app/restart_app.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

class SettingsScreen extends StatefulWidget {
  final User user;
  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _deleteAccount(String password) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No user currently signed in. Please sign in again.'),
          ),
        );
        // Ensure the context is still valid before navigating.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => SignInScreen(),
          ), // Use your SignInScreen widget here
          (route) => false,
        );
      }
      return;
    }
    try {
      // Re-authenticate
      final cred = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );
      await currentUser.reauthenticateWithCredential(cred);
      // Delete Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .delete();
      // Delete Auth account
      await currentUser.delete();
      // Show message before sign out and navigation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account deleted. Please wait 10 seconds before re-registering.',
            ),
          ),
        );
      }
      await FirebaseAuth.instance.signOut();
      await Future.delayed(const Duration(seconds: 10));
      // Navigate to sign-in screen after successful deletion and delay.
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => SignInScreen(),
          ), // Use your SignInScreen widget here
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Failed to delete account.';
      if (e.code == 'wrong-password') {
        msg = 'Wrong password. Please try again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete account: $e')));
      }
    }
  }

  void _confirmDelete() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your password to confirm account deletion for ${widget.user.email}.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final password = passwordController.text;
                  Navigator.of(dialogContext).pop();
                  _deleteAccount(password); // Use the state context
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _showMarkdownDialog(String title, String assetPath) async {
    String content = '';
    try {
      content = await rootBundle.loadString(assetPath);
    } catch (e) {
      content = 'Failed to load $title.';
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(content)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ListTile(
                leading: const Icon(Icons.description, color: Colors.white),
                title: const Text(
                  'Terms of Service',
                  style: TextStyle(color: Colors.white),
                ),
                onTap:
                    () => _showMarkdownDialog(
                      'Terms of Service',
                      'assets/terms_of_service.md',
                    ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip, color: Colors.white),
                title: const Text(
                  'Privacy Policy',
                  style: TextStyle(color: Colors.white),
                ),
                onTap:
                    () => _showMarkdownDialog(
                      'Privacy Policy',
                      'assets/privacy_policy.md',
                    ),
              ),
              const SizedBox(height: 32),
              if (!widget.user.isAnonymous)
                ElevatedButton(
                  onPressed: _confirmDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
