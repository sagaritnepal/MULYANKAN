import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushService.initialize();
  runApp(const ProviderScope(child: MulyankanApp()));
}
