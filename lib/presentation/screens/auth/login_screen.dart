import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:chatzilla/core/common/custom_button.dart';
import 'package:chatzilla/core/common/custom_text_field.dart';
import 'package:chatzilla/core/utils/ui_utils.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/logic/cubit/auth/auth_cubit.dart';
import 'package:chatzilla/logic/cubit/auth/auth_state.dart';
import 'package:chatzilla/presentation/home/home_screen.dart';
import 'package:chatzilla/presentation/screens/auth/signup_screen.dart';
import 'package:chatzilla/router/app_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isPasswordVisible = false;
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email address';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address (e.g., example@email.com)';
    }
    return null;
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  Future<void> handleSignIn() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      try {
        await getIt<AuthCubit>().signIn(
          email: emailController.text,
          password: passwordController.text,
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } else {
      print("form validation failed");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      bloc: getIt<AuthCubit>(),
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          getIt<AppRouter>().pushAndRemoveUntil(const HomeScreen());
        } else if (state.status == AuthStatus.error && state.error != null) {
          UiUtils.showSnackBar(context, message: state.error!);
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 170),
                    Text(
                      "Welcome Back",
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Sign in to continue",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 30),
                    CustomTextField(
                      controller: emailController,
                      hintText: "Email",
                      focusNode: _emailFocus,
                      validator: _validateEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: passwordController,
                      focusNode: _passwordFocus,
                      validator: _validatePassword,
                      hintText: "Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      obscureText: !_isPasswordVisible,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    CustomButton(
                      onPressed: handleSignIn,
                      text: 'Login',
                      child:
                          state.status == AuthStatus.loading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text(
                                "Login",
                                style: TextStyle(color: Colors.white),
                              ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          text: "Don't have an account?  ",
                          style: TextStyle(color: Colors.grey[600]),
                          children: [
                            TextSpan(
                              text: "Sign up",
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer:
                                  TapGestureRecognizer()
                                    ..onTap = () {
                                      // Navigator.push(
                                      //   context,
                                      //   MaterialPageRoute(
                                      //     builder: (context) => const SignupScreen(),
                                      //   ),
                                      // );
                                      getIt<AppRouter>().push(
                                        const SignupScreen(),
                                      );
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
