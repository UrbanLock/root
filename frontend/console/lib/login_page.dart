import 'package:flutter/cupertino.dart';
import 'package:console/core/theme/app_colors.dart';
import 'package:console/core/theme/theme_manager.dart';
import 'package:console/core/api/operator_auth_service.dart';
import 'package:console/home_page.dart';

class LoginPage extends StatefulWidget {
  final ThemeManager themeManager;
  
  const LoginPage({super.key, required this.themeManager});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _usernameError;
  String? _passwordError;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool isValid = true;
    
    if (_usernameController.text.isEmpty) {
      setState(() {
        _usernameError = 'Inserisci il tuo username';
      });
      isValid = false;
    } else {
      setState(() {
        _usernameError = null;
      });
    }
    
    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = 'Inserisci la tua password';
      });
      isValid = false;
    } else {
      setState(() {
        _passwordError = null;
      });
    }
    
    return isValid;
  }

  Future<void> _handleSubmit() async {
    if (!_validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      final result = await OperatorAuthService.login(
        username: username,
        password: password,
      );

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        final user = result['user'] as Map<String, dynamic>;
        final nome = user['nome'] as String? ?? 'Operatore';
        
        if (mounted) {
          // Naviga direttamente alla homepage dopo il login
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (context) => HomePage(themeManager: widget.themeManager),
            ),
          );
        }
      } else {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Errore'),
              content: Text(result['error'] as String? ?? 'Errore durante il login'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Errore'),
            content: Text('Errore di connessione: ${e.toString()}'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeManager.isDarkMode;
    
    return CupertinoPageScaffold(
      backgroundColor: isDark 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icona o logo
                Icon(
                  CupertinoIcons.lock,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 32),
                
                // Titolo
                Text(
                  'Login',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark 
                        ? CupertinoColors.white 
                        : CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Campo Username
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CupertinoTextField(
                      controller: _usernameController,
                      placeholder: 'Inserisci il tuo username',
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? CupertinoColors.darkBackgroundGray 
                            : CupertinoColors.white,
                        border: Border.all(
                          color: _usernameError != null
                              ? CupertinoColors.destructiveRed
                              : CupertinoColors.separator,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(
                          CupertinoIcons.person,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_usernameError != null) {
                          setState(() {
                            _usernameError = null;
                          });
                        }
                      },
                    ),
                    if (_usernameError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          _usernameError!,
                          style: const TextStyle(
                            color: CupertinoColors.destructiveRed,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Campo Password
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CupertinoTextField(
                      controller: _passwordController,
                      placeholder: 'Inserisci la tua password',
                      obscureText: _obscurePassword,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? CupertinoColors.darkBackgroundGray 
                            : CupertinoColors.white,
                        border: Border.all(
                          color: _passwordError != null
                              ? CupertinoColors.destructiveRed
                              : CupertinoColors.separator,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(
                          CupertinoIcons.lock,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      suffix: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 0,
                          child: Icon(
                            _obscurePassword
                                ? CupertinoIcons.eye
                                : CupertinoIcons.eye_slash,
                            color: CupertinoColors.systemGrey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleSubmit(),
                      onChanged: (_) {
                        if (_passwordError != null) {
                          setState(() {
                            _passwordError = null;
                          });
                        }
                      },
                    ),
                    if (_passwordError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          _passwordError!,
                          style: const TextStyle(
                            color: CupertinoColors.destructiveRed,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Pulsante Submit
                CupertinoButton(
                  color: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: AppColors.white)
                      : const Text(
                          'Accedi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
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
