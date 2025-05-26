import 'package:chatzilla/core/common/custom_button.dart';
import 'package:chatzilla/core/common/custom_text_field.dart';
import 'package:chatzilla/core/utils/ui_utils.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/logic/cubit/auth/auth_cubit.dart';
import 'package:chatzilla/logic/cubit/auth/auth_state.dart';
import 'package:chatzilla/presentation/home/home_screen.dart';
import 'package:chatzilla/router/app_router.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  final _nameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _phoneFocus = FocusNode();

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    usernameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    _nameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Please enter your full name";
    }
    if (value.trim().length < 2) {
      return "Name must be at least 2 characters long";
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Please enter your username";
    }
    if (value.trim().length < 3) {
      return "Username must be at least 3 characters long";
    }
    // Check for valid username format (alphanumeric and underscore only)
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value.trim())) {
      return "Username can only contain letters, numbers, and underscores";
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address (e.g., example@email.com)';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }

    // Remove all spaces and dashes for validation
    final cleanPhone = value.replaceAll(RegExp(r'[\s-]'), '');

    // Check if it starts with + and has at least 10 digits
    final phoneRegex = RegExp(r'^\+?[1-9]\d{9,14}$');
    if (!phoneRegex.hasMatch(cleanPhone)) {
      return 'Please enter a valid phone number (e.g., +1234567890)';
    }
    return null;
  }

  Future<void> handleSignUp() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() ?? false) {
      try {
        await getIt<AuthCubit>().signUp(
          fullName: nameController.text.trim(),
          username: usernameController.text.trim(),
          email: emailController.text.trim(),
          phoneNumber: phoneController.text.trim(),
          password: passwordController.text,
        );
      } catch (e) {
        if (mounted) {
          UiUtils.showSnackBar(context, message: e.toString());
        }
      }
    } else {
      print("Form validation failed");
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
        final isLoading = state.status == AuthStatus.loading;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              onPressed: () {
                if (!isLoading) {
                  // Prevent navigation while loading
                  Navigator.pop(context);
                }
              },
              icon: Icon(
                Icons.arrow_back,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Text(
                      "Create Account",
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Please fill in the details to continue",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 30),

                    // Full Name Field
                    CustomTextField(
                      controller: nameController,
                      focusNode: _nameFocus,
                      hintText: "Full Name",
                      validator: _validateName,
                      prefixIcon: const Icon(Icons.person_outline),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _usernameFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Username Field
                    CustomTextField(
                      controller: usernameController,
                      hintText: "Username",
                      focusNode: _usernameFocus,
                      validator: _validateUsername,
                      prefixIcon: const Icon(Icons.alternate_email),
                      textInputAction:
                          TextInputAction.next, // Added missing property
                      onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    CustomTextField(
                      controller: emailController,
                      hintText: "Email",
                      focusNode: _emailFocus,
                      validator: _validateEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Phone Field
                    CustomTextField(
                      controller: phoneController,
                      focusNode: _phoneFocus,
                      validator: _validatePhone,
                      hintText: "Phone Number",
                      prefixIcon: const Icon(Icons.phone_outlined),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    CustomTextField(
                      controller: passwordController,
                      obscureText: !_isPasswordVisible,
                      hintText: "Password",
                      focusNode: _passwordFocus,
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
                      validator: _validatePassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => handleSignUp(),
                    ),
                    const SizedBox(height: 30),

                    // Sign Up Button
                    CustomButton(
                      onPressed: isLoading ? null : handleSignUp,
                      text: "Create Account",
                      child:
                          isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : null, // Ensure child is null when not loading if text is used
                    ),
                    const SizedBox(height: 20),

                    // Login Link
                    Center(
                      child: RichText(
                        text: TextSpan(
                          text: "Already have an account?  ",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                          children: [
                            TextSpan(
                              text: "Login",
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer:
                                  TapGestureRecognizer()
                                    ..onTap = () {
                                      if (!isLoading) {
                                        // Prevent navigation while loading
                                        // Navigate to Login Screen
                                        // Assuming LoginScreen is pushed, so pop to go back
                                        Navigator.pop(context);
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // Added for bottom padding
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
