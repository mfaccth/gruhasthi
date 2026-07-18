import 'package:flutter/material.dart';

import 'data/household_repository.dart';
import 'data/secure_payment_repository.dart';
import 'features/home/home_screen.dart';

class HouseholdApp extends StatelessWidget {
  const HouseholdApp({super.key, this.repository, this.paymentRepository});

  // Nullable during hot reload after this field was introduced. A full app
  // restart creates it in main; the fallback keeps development transitions safe.
  final HouseholdRepository? repository;
  final SecurePaymentRepository? paymentRepository;

  @override
  Widget build(BuildContext context) {
    const pastelPink = Color(0xFFFDE4E8);
    const pastelYellow = Color(0xFFFFF4C8);
    const ink = Color(0xFF43383B);

    return MaterialApp(
      title: 'Gruhasthi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: pastelPink,
          brightness: Brightness.light,
          primary: pastelPink,
          secondary: pastelYellow,
          surface: const Color(0xFFFFF9F8),
          onSurface: ink,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: ink,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
          fontFamily: 'sans-serif',
        ),
      ),
      builder: (context, child) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFBE2E9), Color(0xFFFFF7F1), Color(0xFFFFF5C9)],
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: HomeScreen(
        repository: repository ?? HouseholdRepository(),
        paymentRepository: paymentRepository ?? SecurePaymentRepository(),
      ),
    );
  }
}
