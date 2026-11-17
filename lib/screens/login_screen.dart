import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:login_bear_animation/screens/signup_screen.dart';
import 'package:rive/rive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static final ValueNotifier<bool> isCelebrating = ValueNotifier<bool>(false);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscure = true;
  bool _rememberMe = false;
  bool _rememberMeAnimating = false;
  bool _isLoading = false;

  StateMachineController? _controller;
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;
  SMINumber? _numLook;

  Timer? _typingDebounce;

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String? emailError;
  String? passError;

  bool isValidEmail(String email) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(email);
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Correo o contraseña incorrectos.';
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'operation-not-allowed':
        return 'Habilita Correo/Contraseña en Firebase Console > Authentication.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Intenta más tarde.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Verifica tu red.';
      default:
        return 'Error (${e.code}): ${e.message ?? 'Ocurrió un problema'}';
    }
  }

  Future<void> _onLogin() async {
    if (_isLoading) return;

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    final eError = isValidEmail(email) ? null : 'Correo electrónico inválido';
    final pError = pass.isNotEmpty ? null : 'Ingresa tu contraseña';

    setState(() {
      emailError = eError;
      passError = pError;
    });

    FocusScope.of(context).unfocus();
    _typingDebounce?.cancel();
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    _numLook?.value = 50.0;

    if (eError != null || pError != null) {
      _trigFail?.fire();
      return;
    }

    setState(() => _isLoading = true);
    LoginScreen.isCelebrating.value = true;

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      _trigSuccess?.fire();
      await Future.delayed(const Duration(milliseconds: 1500));

      LoginScreen.isCelebrating.value = false;
    } on FirebaseAuthException catch (e) {
      LoginScreen.isCelebrating.value = false;
      _trigFail?.fire();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mapFirebaseAuthError(e)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      LoginScreen.isCelebrating.value = false;
      _trigFail?.fire();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onForgotPassword() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();
    _typingDebounce?.cancel();
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    _numLook?.value = 50.0;

    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    String? dialogError;
    bool isSending = false;

    final sentToEmail = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendReset() async {
              final targetEmail = resetEmailCtrl.text.trim();
              if (!isValidEmail(targetEmail)) {
                setDialogState(() {
                  dialogError = 'Ingresa un correo electrónico válido.';
                });
                return;
              }

              setDialogState(() {
                dialogError = null;
                isSending = true;
              });

              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: targetEmail,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(targetEmail);
                }
              } on FirebaseAuthException catch (e) {
                setDialogState(() {
                  isSending = false;
                  dialogError = _mapFirebaseAuthError(e);
                });
              } catch (_) {
                setDialogState(() {
                  isSending = false;
                  dialogError = 'No se pudo enviar el correo. Intenta de nuevo.';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Recuperar contraseña'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingresa tu correo registrado y te enviaremos un enlace para restablecer tu contraseña.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailCtrl,
                    enabled: !isSending,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'ejemplo@correo.com',
                      errorText: dialogError,
                      errorMaxLines: 2,
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isSending ? null : sendReset,
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Enviar enlace'),
                ),
              ],
            );
          },
        );
      },
    );

    resetEmailCtrl.dispose();

    if (!mounted) return;

    if (sentToEmail != null) {
      if (_emailCtrl.text.trim().isEmpty) {
        _emailCtrl.text = sentToEmail;
      }
      _trigSuccess?.fire();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '✅ Correo de recuperación enviado a $sentToEmail. Revisa tu bandeja de entrada o spam.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
    }
  }

  void _toggleRememberMe() {
    if (_rememberMeAnimating) return;

    setState(() {
      _rememberMeAnimating = true;
      _rememberMe = !_rememberMe;
    });
  }

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (_emailFocus.hasFocus) {
        _isHandsUp?.change(false);
        _isChecking?.change(true);
        _numLook?.value = 50.0;
      }
    });
    _passwordFocus.addListener(() {
      _isHandsUp?.change(_passwordFocus.hasFocus && _obscure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(
                  width: size.width,
                  height: 200,
                  child: RiveAnimation.asset(
                    'assets/login-bear.riv',
                    stateMachines: const ['Login Machine'],
                    onInit: (artboard) {
                      _controller = StateMachineController.fromArtboard(
                        artboard,
                        'Login Machine',
                      );

                      if (_controller == null) return;
                      artboard.addController(_controller!);
                      _isChecking = _controller!.findSMI('isChecking');
                      _isHandsUp = _controller!.findSMI('isHandsUp');
                      _trigSuccess = _controller!.findSMI('trigSuccess');
                      _trigFail = _controller!.findSMI('trigFail');
                      _numLook = _controller!.findSMI('numLook');
                    },
                  ),
                ),

                const SizedBox(height: 10),
                TextField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  enabled: !_isLoading,
                  onChanged: (value) {
                    if (_isChecking == null) return;
                    _isChecking!.change(true);

                    final look =
                        (value.length / 60.0 * 100.0).clamp(0.0, 100.0);
                    _numLook?.value = look;

                    _typingDebounce?.cancel();
                    _typingDebounce = Timer(const Duration(seconds: 3), () {
                      if (!mounted) return;
                      _isChecking?.change(false);
                    });
                  },
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    errorText: emailError,
                    hintText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                TextField(
                  controller: _passCtrl,
                  focusNode: _passwordFocus,
                  enabled: !_isLoading,
                  onChanged: (value) {
                    if (_isHandsUp == null) return;
                    _isHandsUp!.change(_obscure);
                  },
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    errorText: passError,
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscure = !_obscure;
                        });
                        if (_passwordFocus.hasFocus) {
                          _isHandsUp?.change(_obscure);
                        }
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Enlace Forgot password conectado a sendPasswordResetEmail
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _onForgotPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: Colors.black87,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: _rememberMeAnimating ? null : _toggleRememberMe,
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        onEnd: () {
                          if (mounted) {
                            setState(() {
                              _rememberMeAnimating = false;
                            });
                          }
                        },
                        width: 50,
                        height: 28,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _rememberMe ? Colors.pinkAccent : Colors.grey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          alignment: _rememberMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Remember me'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                MaterialButton(
                  minWidth: size.width,
                  height: 50,
                  color: Colors.pinkAccent,
                  disabledColor: Colors.pinkAccent.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: _isLoading ? null : _onLogin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: size.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                );
                              },
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: Colors.black,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }
}