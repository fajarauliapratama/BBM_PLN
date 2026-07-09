import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'form_bbm_screen.dart';
import 'history_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true; // Variabel baru untuk fitur tombol mata

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- FUNGSI LOGIN ---
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      
      if (_emailController.text.contains('admin')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HistoryScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FormBbmScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Gagal: ${e.message}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- FUNGSI LUPA PASSWORD ---
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    
    // Cek apakah kolom email kosong
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan email Anda di kolom atas terlebih dahulu untuk mereset password.')),
      );
      return;
    }

    try {
      // Perintah Firebase untuk mengirim email reset
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link reset password telah dikirim ke email Anda.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim link: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color plnTeal = Color(0xFF007A93);
    const Color plnBlue = Color(0xFF1E52A8);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // GARIS HEADER ATAS
            Container(
              height: 40,
              width: double.infinity,
              color: plnTeal,
            ),
            
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // LOGO PLN
                      Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/9/97/Logo_PLN.png',
                        height: 70,
                      ),
                      const SizedBox(height: 32),

                      // KOTAK FORM LOGIN
                      Container(
                        width: 340,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Input Email
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'Username atau Email',
                                hintStyle: const TextStyle(fontSize: 14),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderSide: BorderSide.none,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Input Password (Sudah diaktifkan tombol matanya)
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword, // Mengikuti variabel boolean
                              decoration: InputDecoration(
                                hintText: 'Password',
                                hintStyle: const TextStyle(fontSize: 14),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderSide: BorderSide.none,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                // Diubah dari Icon biasa menjadi IconButton agar bisa diklik
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    // Mengubah state untuk memunculkan/menyembunyikan password
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // Checkbox Remember Me
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: plnTeal,
                                    onChanged: (val) {
                                      setState(() => _rememberMe = val!);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Remember Me?', style: TextStyle(fontSize: 13, color: Colors.black54)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // Tombol Sign In
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: plnBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.normal)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Link Lupa Password (Sudah dihubungkan ke fungsi Firebase)
                            Center(
                              child: TextButton(
                                onPressed: _resetPassword,
                                child: const Text('Forgot Password?', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Teks Terms & Privacy
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Privacy Policy', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                          SizedBox(width: 24),
                          Text('Terms', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
            
            // FOOTER UPT PADANG
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              color: plnTeal,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PLN Identity and Access Management',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Copyright © 2026 - PT PLN (Persero) UPT Padang',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}