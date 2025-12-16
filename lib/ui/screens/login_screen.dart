import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/blocs/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            LoginEvent(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated) {
            Navigator.of(context).pushReplacementNamed('/');
          } else if (state.status == AuthStatus.error) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Đăng nhập thất bại'),
                  backgroundColor: Colors.red[600],
                ),
              );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            child: SizedBox(
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top,
              child: Column(
                children: [
                  // === PHẦN TRÊN: LOGO VÀ HÌNH NỀN ===
                  Expanded(
                    flex: 4,
                    child: Stack(
                      children: [
                        // Hình trang trí góc phải trên
                        Positioned(
                          top: -50,
                          right: -50,
                          child: _buildDecorativeShape(150, Colors.red[400]!),
                        ),
                        Positioned(
                          top: 30,
                          right: 20,
                          child: _buildDecorativeShape(60, Colors.red[300]!),
                        ),
                        Positioned(
                          top: 100,
                          right: 80,
                          child: _buildDecorativeShape(30, Colors.red[200]!),
                        ),
                        // Hình trang trí góc trái
                        Positioned(
                          top: 80,
                          left: -30,
                          child: _buildDecorativeShape(80, Colors.red[300]!),
                        ),
                        Positioned(
                          top: 180,
                          left: 10,
                          child: _buildDecorativeShape(40, Colors.red[200]!),
                        ),
                        // Logo ở giữa
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo ASTEC từ ảnh
                              Image.asset(
                                'assets/images/logo_astec.jpg',
                                width: 180,
                                height: 180,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback nếu không load được ảnh
                                  return Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.red[700]!, Colors.red[400]!],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'SG',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              // Tên công ty
                              Text(
                                'ASTEC GROUP',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // === PHẦN DƯỚI: FORM ĐĂNG NHẬP ===
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Email field
                            _buildTextField(
                              controller: _emailController,
                              hintText: 'Email',
                              prefixIcon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vui lòng nhập email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password field
                            _buildTextField(
                              controller: _passwordController,
                              hintText: 'Password',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey[500],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vui lòng nhập mật khẩu';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 40),

                            // Login button
                            BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                final isLoading =
                                    state.status == AuthStatus.loading;
                                return Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.red[700]!,
                                        Colors.red[400]!,
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _onLoginPressed,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Đăng nhập',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),

                            // Forgot password
                            TextButton(
                              onPressed: () {
                                // TODO: Implement forgot password
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Vui lòng liên hệ Admin để đặt lại mật khẩu'),
                                  ),
                                );
                              },
                              child: Text(
                                'Quên mật khẩu?',
                                style: TextStyle(
                                  color: Colors.red[600],
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Hình trang trí góc dưới
                  SizedBox(
                    height: 80,
                    child: Stack(
                      children: [
                        Positioned(
                          bottom: -20,
                          left: -30,
                          child: _buildDecorativeShape(100, Colors.red[300]!),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 60,
                          child: _buildDecorativeShape(40, Colors.red[200]!),
                        ),
                      ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 20, right: 10),
            child: Icon(
              prefixIcon,
              color: Colors.grey[500],
              size: 24,
            ),
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          errorStyle: const TextStyle(height: 0.8),
        ),
      ),
    );
  }

  Widget _buildDecorativeShape(double size, Color color) {
    return Transform.rotate(
      angle: 0.5,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.8),
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
      ),
    );
  }

  Widget _buildPixel(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
