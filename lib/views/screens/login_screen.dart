import 'package:flutter/material.dart';
import 'credential_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const CredentialScreen(mode: CredentialMode.login);
}
