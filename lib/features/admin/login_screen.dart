import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passcodeController = TextEditingController();
  bool _isLoading = false;

  // 🔒 HIDE EMAIL HERE: Change this to the exact email you registered in Supabase
  static const String _hiddenAdminEmail = 'admin@admin.com';

  Future<void> _handlePasscodeLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // The user only sees the passcode field, but we send the hidden email in the background
      final response =
          await SupabaseService.instance.client.auth.signInWithPassword(
        email: _hiddenAdminEmail,
        password: _passcodeController.text
            .trim(), // Your 4-digit passcode acts as the password
      );

      if (mounted && response.session != null) {
        context.go('/admin');
      }
    } catch (_) {
      _showError('Incorrect passcode. Access denied.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 48, color: Colors.black87),
                      const SizedBox(height: 16),
                      Text(
                        'Admin Verification',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your 4-digit PIN to unlock',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _passcodeController,
                        decoration: const InputDecoration(
                          labelText: 'Passcode',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.pin_outlined),
                          counterText:
                              '', // Hides character count text at bottom
                        ),
                        obscureText: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26, letterSpacing: 12),
                        keyboardType: TextInputType.number,
                        maxLength: 4, // 🔑 Enforces exactly 4 digits maximum
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly, // Only opens number pad / allows digits
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (value.length < 4) {
                            return 'Must be 4 digits';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handlePasscodeLogin(),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handlePasscodeLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Unlock',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
