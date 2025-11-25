import 'package:flutter/material.dart';
import 'screens/home.dart'; // Importa il file della home page

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(), // Qui colleghi la tua home separata
    );
  }
}
