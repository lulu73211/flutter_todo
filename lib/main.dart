import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'auth/auth.dart';
import 'login_page.dart';
import 'todo_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  AuthGate({super.key});
  final auth = Auth();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const LoginPage(); // pas connecté → login
        }
        return const TodoPage(); // connecté → Todo list
      },
    );
  }
}
