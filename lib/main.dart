import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:login_bear_animation/firebase_options.dart';
import 'package:login_bear_animation/screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<FirebaseApp> _firebaseInit;
  late final Stream<User?> _authStream;
  bool _connectionConfirmed = false;

  @override
  void initState() {
    super.initState();
    _firebaseInit = _initializeFirebase();
  }

  Future<FirebaseApp> _initializeFirebase() async {
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _authStream = FirebaseAuth.instance.authStateChanges();
    debugPrint('✅ Firebase inicializado correctamente: ${app.name}');
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() => _connectionConfirmed = true);
    }
    return app;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login Bear Auth',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: FutureBuilder<FirebaseApp>(
        future: _firebaseInit,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error al conectar con Firebase: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState != ConnectionState.done ||
              !_connectionConfirmed) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.pinkAccent),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.connectionState == ConnectionState.done
                          ? '✅ Conexión con Firebase exitosa'
                          : 'Conectando con Firebase...',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          }

          return ValueListenableBuilder<bool>(
            valueListenable: LoginScreen.isCelebrating,
            builder: (context, isCelebrating, _) {
              return StreamBuilder<User?>(
                stream: _authStream,
                builder: (context, authSnapshot) {
                  if (authSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final user = authSnapshot.data;
                  if (user != null && !isCelebrating) {
                    return _AuthenticatedHomeScreen(
                      key: ValueKey('home_${user.uid}'),
                      user: user,
                    );
                  }

                  return const LoginScreen(
                    key: ValueKey('clean_login_screen'),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AuthenticatedHomeScreen extends StatefulWidget {
  final User user;

  const _AuthenticatedHomeScreen({super.key, required this.user});

  @override
  State<_AuthenticatedHomeScreen> createState() =>
      _AuthenticatedHomeScreenState();
}

class _AuthenticatedHomeScreenState extends State<_AuthenticatedHomeScreen> {
  bool _isSigningOut = false;

  Future<void> _handleSignOut() async {
    if (_isSigningOut) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSigningOut = true);

    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      LoginScreen.isCelebrating.value = false;
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cerrar sesión: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (widget.user.displayName != null &&
            widget.user.displayName!.isNotEmpty)
        ? widget.user.displayName!
        : 'Usuario autenticado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesión Activa'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _isSigningOut ? null : _handleSignOut,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user, size: 72, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                '¡Bienvenido, $displayName!',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                widget.user.email ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 220,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSigningOut ? null : _handleSignOut,
                  icon: _isSigningOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}