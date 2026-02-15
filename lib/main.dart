import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cgxnjbdmlyzkcnflyaeu.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNneG5qYmRtbHl6a2NuZmx5YWV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNTUwNjUsImV4cCI6MjA4NjczMTA2NX0.54BgNe_jCo5zgHer_4QhlB6gs-VcDRNwNmkpeOo9MYg',
  );

  runApp(const ProviderScope(child: InkTokenApp()));
}
