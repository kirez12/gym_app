import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  final bool isLinking; 
  
  const LoginScreen({super.key, this.isLinking = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  late bool _isLogin;

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.isLinking; 
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email and a password (min 6 chars).'), backgroundColor: Colors.redAccent)
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      } else {
        final credential = EmailAuthProvider.credential(email: email, password: password);
        final currentUser = FirebaseAuth.instance.currentUser;
        
        if (currentUser != null && currentUser.isAnonymous) {
          await currentUser.linkWithCredential(credential);
        } else {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
        }
      }

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return; 
      
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication failed'), backgroundColor: Colors.redAccent)
      );
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      if (!mounted) return; 
      
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to login as guest'), backgroundColor: Colors.redAccent)
      );
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    
    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSending = false;
        
        return StatefulBuilder(
          builder: (stateContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey.shade900,
              title: const Text('Reset Password', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your email address and we will send you a link to reset your password.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: isSending ? null : () async {
                    final email = resetEmailController.text.trim();
                    if (email.isEmpty) return;

                    setDialogState(() => isSending = true);

                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                      
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password reset email sent!'), backgroundColor: Colors.green)
                      );
                    } on FirebaseAuthException catch (e) {
                      setDialogState(() => isSending = false);
                      
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message ?? 'Failed to send reset email'), backgroundColor: Colors.redAccent)
                      );
                    }
                  },
                  child: isSending 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Send Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isLinking ? AppBar(backgroundColor: Colors.transparent, elevation: 0) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fitness_center, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 24),
                Text(
                  _isLogin ? 'Welcome Back' : 'Secure Account', 
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin ? 'Log in to access your data.' : 'Create an email and password to save your data.', 
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),

                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text('Forgot Password?', style: TextStyle(color: Colors.blueAccent)),
                    ),
                  )
                else
                  const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitAuth,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isLogin ? 'Log In' : 'Sign Up', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? "Don't have an account? Sign Up" : "Already have an account? Log In", 
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 14)
                  ),
                ),

                if (!widget.isLinking) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isLoading ? null : _continueAsGuest,
                    child: const Text('Continue as Guest', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}