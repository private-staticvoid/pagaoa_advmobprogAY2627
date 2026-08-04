import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';


// Theme settings page.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

// Stores settings page state.
class _SettingsPageState extends State<SettingsPage> {

  // Tracks if the theme was changed.
  bool themeChanged = false;

  @override
  Widget build(BuildContext context) {

    final themeModel = Provider.of<ThemeProvider>(context);

    return Scaffold(

      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,

        // Returns false if no theme change happened.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, themeChanged);
          },
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          Container(
            padding: const EdgeInsets.symmetric(vertical: 30),

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
                    Icons.palette,
                    size: 35,
                  ),
                ),

                SizedBox(height: 12),

                Text(
                  "Appearance",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  "Customize your app theme",
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          Card(
            elevation: 3,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),

            child: SwitchListTile(

              secondary: Text(
                themeModel.isDark ? "🌙" : "🌞",
                style: const TextStyle(fontSize: 26),
              ),

              title: Text(
                themeModel.isDark
                    ? "Night Mode"
                    : "Day Mode",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              subtitle: Text(
                themeModel.isDark
                    ? "Dark theme enabled"
                    : "Light theme enabled",
              ),

              value: themeModel.isDark,

              // Changes theme and records the change.
              onChanged: (_) {

                themeModel.toggleTheme();

                setState(() {
                  themeChanged = true;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}