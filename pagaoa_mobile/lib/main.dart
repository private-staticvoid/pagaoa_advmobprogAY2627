import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings.dart';

// Starts the app and provides the theme state globally using Provider.
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeModel(),
      child: const MyApp(),
    ),
  );
}

// Manages the app theme state shared across the application.
class ThemeModel with ChangeNotifier {
  bool _isDark = false;

  // Returns the current theme mode.
  bool get isDark => _isDark;

  // Switches between light and dark mode and updates the UI.
  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

// Root widget that builds the application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeModel = Provider.of<ThemeModel>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ephemeral vs. App State',

      // Applies the theme managed by Provider.
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness:
            themeModel.isDark ? Brightness.dark : Brightness.light,
      ),

      home: const MyHomePage(),
    );
  }
}

// Creates the home page where local state is used.
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// Stores ephemeral state that only exists inside this page.
class _MyHomePageState extends State<MyHomePage> {

  // Temporary counter data that resets only when theme changes.
  int _counter = 0;

  // Updates the counter value.
  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // App bar containing title and settings button.
      appBar: AppBar(
        title: const Text('App State'),
        centerTitle: true,
        elevation: 0,

        actions: [

          // Opens settings page.
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',

            onPressed: () async {

              // Receives true only when theme changes.
              final bool? themeChanged = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );

              // Resets counter only when theme changes.
              if (themeChanged == true) {
                setState(() {
                  _counter = 0;
                });
              }
            },
          ),
        ],
      ),

      // Displays the main UI content.
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // Shows explanation of ephemeral state.
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 30,
              horizontal: 20,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),

            child: const Column(
              children: [

                CircleAvatar(
                  radius: 35,
                  child: Icon(
                    Icons.memory,
                    size: 35,
                  ),
                ),

                SizedBox(height: 12),

                Text(
                  'Ephemeral State',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  'Ephemeral state is temporary data for the increment.\n'
                  'Whenever the theme changes, the counter resets to zero.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Displays counter value.
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),

            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 28,
                horizontal: 20,
              ),

              child: Column(
                children: [

                  const Icon(
                    Icons.add_circle_outline,
                    size: 45,
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Counter',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Shows current counter value.
                  Text(
                    '$_counter',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Tap the + button to increase the counter.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Button that increments the counter.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _incrementCounter,
        icon: const Icon(Icons.add),
        label: const Text('Increment'),
      ),
    );
  }
}