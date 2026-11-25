import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

void main() => runApp(const FarmMindApp());

const green = Color(0xFF237A48);
const ink = Color(0xFF20312A);
const muted = Color(0xFF77827B);
const canvas = Color(0xFFF5F7F4);
const apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

class FarmMindApp extends StatelessWidget {
  const FarmMindApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FarmMind',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        surface: Colors.white,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
      ),
    ),
    home: const LoginScreen(),
  );
}

class Farm {
  Farm(this.name, this.location, this.area, {this.crops = 0, this.id});
  String name, location;
  double area;
  int crops;
  int? id;
}

class Crop {
  Crop(this.name, this.farm, this.date, this.moisture, this.status, {this.id});
  String name, farm, date, status;
  int moisture;
  int? id;
}

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._();
  AppState._();
  String farmer = 'Farmer';
  String? token;
  final farms = <Farm>[];
  final crops = <Crop>[];
  final history = <String>[];
  Map<String, String> get headers => {
    'Authorization': 'Bearer ${token ?? ''}',
    'Content-Type': 'application/json',
  };
  Future<void> loadFromApi() async {
    if (token == null) return;
    final fr = await http
        .get(Uri.parse('$apiBase/api/farms'), headers: headers)
        .timeout(const Duration(seconds: 5));
    final cr = await http
        .get(Uri.parse('$apiBase/api/crops'), headers: headers)
        .timeout(const Duration(seconds: 5));
    if (fr.statusCode != 200 || cr.statusCode != 200) return;
    farms
      ..clear()
      ..addAll(
        (jsonDecode(fr.body) as List).map(
          (x) => Farm(
            x['name'],
            x['location'],
            (x['area'] as num).toDouble(),
            id: x['id'],
          ),
        ),
      );
    crops
      ..clear()
      ..addAll(
        (jsonDecode(cr.body) as List).map(
          (x) => Crop(
            x['cropType'],
            x['farmName'],
            x['plantingDate'],
            0,
            x['status'],
            id: x['id'],
          ),
        ),
      );
    for (final c in crops) {
      if (c.id == null) continue;
      try {
        final sm = await http.get(
          Uri.parse('$apiBase/api/soil-measurements/${c.id}'),
          headers: headers,
        );
        if (sm.statusCode == 200) {
          final readings = jsonDecode(sm.body) as List;
          if (readings.isNotEmpty)
            c.moisture = readings.first['moisturePercentage'];
        }
        final scans = await http.get(
          Uri.parse('$apiBase/api/scans/${c.id}'),
          headers: headers,
        );
        if (scans.statusCode == 200) {
          for (final x in jsonDecode(scans.body) as List) {
            history.add('Plant scan · ${c.name} · ${x['predictedDisease']}');
          }
        }
        final irrigations = await http.get(
          Uri.parse('$apiBase/api/irrigation/${c.id}'),
          headers: headers,
        );
        if (irrigations.statusCode == 200) {
          for (final x in jsonDecode(irrigations.body) as List) {
            history.add(
              'Irrigation recorded · ${c.name} · ${x['waterAmount']} L',
            );
          }
        }
      } catch (_) {}
    }
    for (final f in farms) {
      f.crops = crops.where((c) => c.farm == f.name).length;
    }
    notifyListeners();
  }

  Future<void> addFarm(Farm f) async {
    if (token != null) {
      try {
        final r = await http.post(
          Uri.parse('$apiBase/api/farms'),
          headers: headers,
          body: jsonEncode({
            'name': f.name,
            'location': f.location,
            'area': f.area,
          }),
        );
        if (r.statusCode == 201) f.id = jsonDecode(r.body)['id'];
      } catch (_) {}
    }
    farms.add(f);
    notifyListeners();
  }

  Future<void> updateFarm(Farm f) async {
    if (token != null && f.id != null) {
      try {
        await http.put(
          Uri.parse('$apiBase/api/farms/${f.id}'),
          headers: headers,
          body: jsonEncode({
            'name': f.name,
            'location': f.location,
            'area': f.area,
          }),
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> deleteFarm(Farm f) async {
    if (token != null && f.id != null) {
      try {
        await http.delete(
          Uri.parse('$apiBase/api/farms/${f.id}'),
          headers: headers,
        );
      } catch (_) {}
    }
    farms.remove(f);
    crops.removeWhere((c) => c.farm == f.name);
    notifyListeners();
  }

  Future<void> recordSoil(Crop c, int moisture) async {
    c.moisture = moisture;
    if (token != null && c.id != null) {
      try {
        await http.post(
          Uri.parse('$apiBase/api/soil-measurements'),
          headers: headers,
          body: jsonEncode({'cropId': c.id, 'moisturePercentage': moisture}),
        );
      } catch (_) {}
    }
    history.insert(0, 'Soil moisture updated · ${c.name} · Today');
    notifyListeners();
  }

  Future<void> deleteCrop(Crop c) async {
    if (token != null && c.id != null) {
      try {
        await http.delete(
          Uri.parse('$apiBase/api/crops/${c.id}'),
          headers: headers,
        );
      } catch (_) {}
    }
    crops.remove(c);
    final farm = farms.where((f) => f.name == c.farm);
    if (farm.isNotEmpty) farm.first.crops--;
    notifyListeners();
  }

  Future<void> updateCrop(Crop c) async {
    final farm = farms.where((f) => f.name == c.farm);
    if (token != null &&
        c.id != null &&
        farm.isNotEmpty &&
        farm.first.id != null) {
      try {
        await http.put(
          Uri.parse('$apiBase/api/crops/${c.id}'),
          headers: headers,
          body: jsonEncode({
            'farmId': farm.first.id,
            'cropType': c.name,
            'plantingDate':
                DateTime.tryParse(c.date)?.toIso8601String().substring(0, 10) ??
                DateTime.now().toIso8601String().substring(0, 10),
            'growthStage': 'Seedling',
            'status': c.status,
          }),
        );
      } catch (_) {}
    }
    if (token != null && c.id != null) {
      try {
        await http.post(
          Uri.parse('$apiBase/api/soil-measurements'),
          headers: headers,
          body: jsonEncode({'cropId': c.id, 'moisturePercentage': c.moisture}),
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> addCrop(Crop c) async {
    final found = farms.where((x) => x.name == c.farm);
    final farm = found.isEmpty ? null : found.first;
    if (token != null && farm?.id != null) {
      try {
        final r = await http.post(
          Uri.parse('$apiBase/api/crops'),
          headers: headers,
          body: jsonEncode({
            'farmId': farm!.id,
            'cropType': c.name,
            'plantingDate': DateTime.now().toIso8601String().substring(0, 10),
            'growthStage': 'Seedling',
            'status': c.status,
          }),
        );
        if (r.statusCode == 201) {
          c.id = jsonDecode(r.body)['id'];
          await http.post(
            Uri.parse('$apiBase/api/soil-measurements'),
            headers: headers,
            body: jsonEncode({
              'cropId': c.id,
              'moisturePercentage': c.moisture,
            }),
          );
        }
      } catch (_) {}
    }
    crops.add(c);
    if (farm != null) farm.crops++;
    history.insert(0, 'Crop added · ${c.name} · Today');
    notifyListeners();
  }

  Future<void> recordIrrigation(Crop c, double amount) async {
    if (token != null && c.id != null) {
      try {
        await http.post(
          Uri.parse('$apiBase/api/irrigation'),
          headers: headers,
          body: jsonEncode({
            'cropId': c.id,
            'waterAmount': amount,
            'soilMoisture': c.moisture,
            'notes': 'Recorded in FarmMind',
          }),
        );
      } catch (_) {}
    }
    addEvent('Irrigation recorded · ${c.name} · Today');
  }

  void addEvent(String event) {
    history.insert(0, event);
    notifyListeners();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), pass = TextEditingController();
  bool loading = false;
  Future<void> login() async {
    setState(() => loading = true);
    var offline = false;
    try {
      final r = await http
          .post(
            Uri.parse('$apiBase/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.text, 'password': pass.text}),
          )
          .timeout(const Duration(seconds: 5));
      if (r.statusCode >= 400) {
        if (mounted) {
          setState(() => loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                r.statusCode < 500
                    ? 'Email or password is incorrect.'
                    : 'The server could not sign you in. Try again.',
              ),
            ),
          );
        }
        return;
      }
      final data = jsonDecode(r.body);
      AppState.instance.token = data['token'];
      AppState.instance.farmer = data['user']['fullName'];
      await AppState.instance.loadFromApi();
    } catch (_) {
      offline = true;
      AppState.instance.token = null;
      AppState.instance.farmer = email.text.isEmpty
          ? 'Farmer'
          : email.text.split('@').first;
    }
    if (!mounted) return;
    setState(() => loading = false);
    if (offline)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backend unavailable. Opened local preview; data will not sync.',
          ),
        ),
      );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 26),
              const BrandMark(),
              const SizedBox(height: 34),
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to continue caring for your farm.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 28),
              Field(
                controller: email,
                label: 'Email address',
                icon: Icons.mail_outline,
              ),
              const SizedBox(height: 14),
              Field(
                controller: pass,
                label: 'Password',
                icon: Icons.lock_outline,
                obscure: true,
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: loading ? null : login,
                style: primaryButton,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    loading ? 'Connecting…' : 'Sign in',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text('New to FarmMind?  Create account'),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Offline preview is available · Connect backend for account sync',
                  style: TextStyle(color: muted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController(),
      email = TextEditingController(),
      pass = TextEditingController();
  bool busy = false;
  Future<void> register() async {
    setState(() => busy = true);
    try {
      final r = await http
          .post(
            Uri.parse('$apiBase/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': name.text,
              'email': email.text,
              'password': pass.text,
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (r.statusCode >= 400)
        throw Exception(
          (jsonDecode(r.body)['error'] ?? 'Could not create account')
              .toString(),
        );
      final data = jsonDecode(r.body);
      AppState.instance.token = data['token'];
      AppState.instance.farmer = data['user']['fullName'];
      await AppState.instance.loadFromApi();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create account')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Field(
            controller: name,
            label: 'Full name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
          Field(
            controller: email,
            label: 'Email address',
            icon: Icons.mail_outline,
          ),
          const SizedBox(height: 14),
          Field(
            controller: pass,
            label: 'Password · at least 8 characters',
            icon: Icons.lock_outline,
            obscure: true,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: primaryButton,
              onPressed: busy ? null : register,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(busy ? 'Creating account…' : 'Create account'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  final pages = const [
    DashboardScreen(),
    FarmsScreen(),
    CropsScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: pages[tab]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.landscape_outlined),
          label: 'Farms',
        ),
        NavigationDestination(icon: Icon(Icons.spa_outlined), label: 'Crops'),
        NavigationDestination(icon: Icon(Icons.timeline), label: 'History'),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
    floatingActionButton: tab == 0
        ? FloatingActionButton.extended(
            backgroundColor: green,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanScreen()),
            ),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan plant'),
          )
        : null,
  );
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppState.instance,
    builder: (context, _) {
      final s = AppState.instance;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
        children: [
          Row(
            children: [
              const BrandMark(small: true),
              const Spacer(),
              CircleAvatar(
                backgroundColor: const Color(0xFFE3EFE6),
                child: Text(
                  s.farmer.isNotEmpty ? s.farmer[0] : 'F',
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            'Good morning, ${s.farmer.split(' ').first} 👋',
            style: const TextStyle(
              color: ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Here’s what’s happening on your farm today.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 22),
          const WeatherCard(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'My farms',
                  value: '${s.farms.length}',
                  icon: Icons.landscape,
                  color: green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: 'Active crops',
                  value: '${s.crops.length}',
                  icon: Icons.spa,
                  color: const Color(0xFFE7A83E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Healthy',
                  value:
                      '${s.crops.where((c) => c.status == 'Healthy').length}',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF55A271),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  title: 'Needs attention',
                  value:
                      '${s.crops.where((c) => c.status != 'Healthy').length}',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFD47A50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          SectionHeading(
            'Crop health',
            action: 'View all',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CropListPage()),
            ),
          ),
          const SizedBox(height: 10),
          ...s.crops.take(3).map((c) => CropTile(crop: c)),
          const SizedBox(height: 18),
          SectionHeading('Recent activity'),
          const SizedBox(height: 10),
          ...s.history.take(3).map((h) => ActivityTile(text: h)),
        ],
      );
    },
  );
}

class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});
  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  Future<Map<String, dynamic>> weather() async {
    final r = await http
        .get(Uri.parse('$apiBase/api/weather'))
        .timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) throw Exception('Weather unavailable');
    return jsonDecode(r.body);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: weather(),
    builder: (context, s) {
      final data = s.data;
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF234B38),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WEATHER · GIZA',
                    style: TextStyle(
                      color: Color(0xFFB9D6C2),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.hasError
                        ? 'Weather unavailable'
                        : data?['condition'] ?? 'Loading forecast…',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    s.hasError
                        ? 'Check connection; irrigation uses manual soil readings'
                        : data == null
                        ? 'Loading local forecast…'
                        : 'Humidity ${data['humidity']}% · Rain ${data['rainProbability']}%',
                    style: const TextStyle(
                      color: Color(0xFFD7E7DC),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              s.hasError ? Icons.cloud_off_outlined : Icons.wb_sunny_rounded,
              color: const Color(0xFFFFD477),
              size: 40,
            ),
            const SizedBox(width: 8),
            Text(
              data == null ? '--°' : '${data['temperature']}°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String title, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        Text(title, style: const TextStyle(color: muted, fontSize: 12)),
      ],
    ),
  );
}

class FarmsScreen extends StatelessWidget {
  const FarmsScreen({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppState.instance,
    builder: (context, _) {
      final state = AppState.instance;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PageTitle('My farms', 'Manage your growing spaces'),
          const SizedBox(height: 18),
          if (state.farms.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'No farms yet. Add a farm to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
            ),
          ...state.farms.map(
            (f) => CardShell(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.landscape, color: green, size: 32),
                title: Text(
                  f.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${f.location}  ·  ${f.area} ha  ·  ${f.crops} crops',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddFarmScreen(farm: f),
                        ),
                      );
                    } else if (v == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete farm?'),
                          content: Text(
                            'Delete ${f.name} and its crops and history?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await state.deleteFarm(f);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddFarmScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add a farm'),
          ),
        ],
      );
    },
  );
}

class AddFarmScreen extends StatefulWidget {
  const AddFarmScreen({super.key, this.farm});
  final Farm? farm;
  @override
  State<AddFarmScreen> createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends State<AddFarmScreen> {
  final n = TextEditingController(),
      l = TextEditingController(),
      a = TextEditingController();
  @override
  void initState() {
    super.initState();
    final f = widget.farm;
    if (f != null) {
      n.text = f.name;
      l.text = f.location;
      a.text = f.area.toString();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.farm == null ? 'Add a farm' : 'Edit farm'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Field(controller: n, label: 'Farm name', icon: Icons.landscape),
          const SizedBox(height: 14),
          Field(
            controller: l,
            label: 'Location',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 14),
          Field(
            controller: a,
            label: 'Area (hectares)',
            icon: Icons.square_foot,
            keyboard: TextInputType.number,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: primaryButton,
              onPressed: () async {
                final area = double.tryParse(a.text);
                if (n.text.trim().isEmpty ||
                    l.text.trim().isEmpty ||
                    area == null ||
                    area <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a name, location and positive farm area.',
                      ),
                    ),
                  );
                  return;
                }
                final existing = widget.farm;
                if (existing == null) {
                  await AppState.instance.addFarm(
                    Farm(n.text.trim(), l.text.trim(), area),
                  );
                } else {
                  final oldName = existing.name;
                  existing.name = n.text.trim();
                  existing.location = l.text.trim();
                  existing.area = area;
                  for (final crop in AppState.instance.crops.where(
                    (c) => c.farm == oldName,
                  )) {
                    crop.farm = existing.name;
                  }
                  await AppState.instance.updateFarm(existing);
                }
                if (mounted) Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(widget.farm == null ? 'Save farm' : 'Update farm'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CropsScreen extends StatelessWidget {
  const CropsScreen({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppState.instance,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageTitle('My crops', 'Monitor growth and crop health'),
        const SizedBox(height: 18),
        ...AppState.instance.crops.map((c) => CropTile(crop: c, large: true)),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCropScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add a crop'),
        ),
      ],
    ),
  );
}

class CropListPage extends StatelessWidget {
  const CropListPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crop health')),
    body: const CropsScreen(),
  );
}

class AddCropScreen extends StatefulWidget {
  const AddCropScreen({super.key, this.crop});
  final Crop? crop;
  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  String type = 'Tomato', farm = '';
  final moisture = TextEditingController(text: '45');
  final types = ['Tomato', 'Potato', 'Corn', 'Wheat', 'Pepper'];
  @override
  void initState() {
    super.initState();
    final fs = AppState.instance.farms;
    if (fs.isNotEmpty) farm = fs.first.name;
    if (widget.crop != null) {
      type = widget.crop!.name;
      farm = widget.crop!.farm;
      moisture.text = widget.crop!.moisture.toString();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.crop == null ? 'Add a crop' : 'Edit crop'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Crop type',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: type,
            items: types
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => type = v!),
            decoration: inputDecoration(Icons.spa_outlined),
          ),
          const SizedBox(height: 16),
          const Text('Farm', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: farm.isEmpty ? null : farm,
            items: AppState.instance.farms
                .map(
                  (f) => DropdownMenuItem(value: f.name, child: Text(f.name)),
                )
                .toList(),
            onChanged: (v) => setState(() => farm = v ?? ''),
            decoration: inputDecoration(Icons.landscape),
          ),
          const SizedBox(height: 16),
          Field(
            controller: moisture,
            label: 'Current soil moisture (%)',
            icon: Icons.water_drop_outlined,
            keyboard: TextInputType.number,
          ),
          const Spacer(),
          FilledButton(
            style: primaryButton,
            onPressed: () async {
              if (farm.isEmpty) {
                return;
              }
              final parsedMoisture = int.tryParse(moisture.text);
              if (parsedMoisture == null ||
                  parsedMoisture < 0 ||
                  parsedMoisture > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter soil moisture from 0 to 100.'),
                  ),
                );
                return;
              }
              final currentMoisture = int.tryParse(moisture.text) ?? 45;
              final existing = widget.crop;
              if (existing == null) {
                await AppState.instance.addCrop(
                  Crop(
                    type,
                    farm,
                    'Planted today',
                    currentMoisture,
                    currentMoisture < 30 ? 'Needs attention' : 'Healthy',
                  ),
                );
              } else {
                final previousFarm = existing.farm;
                existing.name = type;
                existing.farm = farm;
                existing.moisture = currentMoisture;
                existing.status = currentMoisture < 30
                    ? 'Needs attention'
                    : 'Healthy';
                if (previousFarm != farm) {
                  final oldFarm = AppState.instance.farms.where(
                    (f) => f.name == previousFarm,
                  );
                  final newFarm = AppState.instance.farms.where(
                    (f) => f.name == farm,
                  );
                  if (oldFarm.isNotEmpty) oldFarm.first.crops--;
                  if (newFarm.isNotEmpty) newFarm.first.crops++;
                }
                await AppState.instance.updateCrop(existing);
              }
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(widget.crop == null ? 'Add crop' : 'Update crop'),
            ),
          ),
        ],
      ),
    ),
  );
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  XFile? image;
  Uint8List? imageBytes;
  int? selectedCropId;
  bool busy = false;
  String? result;
  Future<void> pick(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() {
      image = f;
      imageBytes = bytes;
    });
    await analyze();
  }

  Future<void> analyze() async {
    if (image == null) return;
    setState(() => busy = true);
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBase/api/scans').replace(
          queryParameters: selectedCropId == null
              ? null
              : {'cropId': '$selectedCropId'},
        ),
      );
      if (AppState.instance.token != null)
        req.headers['Authorization'] = 'Bearer ${AppState.instance.token}';
      req.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes!,
          filename: image!.name,
          contentType: http.MediaType.parse(image!.mimeType ?? 'image/jpeg'),
        ),
      );
      final res = await req.send().timeout(const Duration(seconds: 20));
      final body = jsonDecode(await res.stream.bytesToString());
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (body['supported'] == false) {
          setState(
            () => result =
                body['message']?.toString() ??
                'The image could not be classified. Try a clearer leaf photo.',
          );
        } else {
          final symptoms = (body['symptoms'] as List? ?? const []).join(' · ');
          final actions = (body['preventive_actions'] as List? ?? const [])
              .join('\n• ');
          setState(
            () => result =
                'Possible ${body['plant'] ?? 'plant'} · ${body['predicted_disease'] ?? 'classification'}\nConfidence ${((body['confidence'] ?? 0) * 100).toStringAsFixed(0)}%\n\nPossible symptoms: $symptoms\n\nPreventive actions:\n• $actions\n\n${body['disclaimer'] ?? 'Possible classification only, not a confirmed diagnosis.'}\nAnalyzed ${DateTime.now().toLocal()}',
          );
        }
      } else {
        final detail = body is Map
            ? (body['error'] ??
                  body['detail'] ??
                  'Analysis service unavailable')
            : 'Analysis service unavailable';
        setState(() => result = detail.toString());
      }
    } catch (_) {
      setState(
        () => result =
            'Could not reach the analysis service. Check your connection and try again.',
      );
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan a plant')),
    body: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 230,
            decoration: BoxDecoration(
              color: const Color(0xFFE6EFE8),
              borderRadius: BorderRadius.circular(22),
            ),
            child: image == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.eco_outlined, color: green, size: 56),
                      SizedBox(height: 12),
                      Text(
                        'Capture a clear leaf photo',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      Text(
                        'Use good lighting and focus on one leaf',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  )
                : Center(
                    child: Text(
                      image!.name,
                      style: const TextStyle(color: ink),
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            initialValue: selectedCropId,
            decoration: inputDecoration(
              Icons.spa_outlined,
            ).copyWith(labelText: 'Save scan to crop history (optional)'),
            items: AppState.instance.crops
                .where((c) => c.id != null)
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() => selectedCropId = v),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => pick(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Take a photo'),
          ),
          OutlinedButton.icon(
            onPressed: () => pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery'),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (result != null)
            CardShell(
              child: Text(result!, style: const TextStyle(height: 1.5)),
            ),
          const Spacer(),
          const Text(
            'Results are possible classifications, not a confirmed diagnosis. Image predictions can be inaccurate.',
            style: TextStyle(color: muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppState.instance,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageTitle('Crop history', 'Your farm activity over time'),
        const SizedBox(height: 18),
        ...AppState.instance.history.map((h) => ActivityTile(text: h)),
        const SizedBox(height: 24),
        const SectionHeading('Irrigation planner'),
        const SizedBox(height: 8),
        const Text(
          'Recommendations are based on crop type, growth stage, soil moisture and local forecast.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 12),
        ...AppState.instance.crops.map((c) => IrrigationCard(crop: c)),
      ],
    ),
  );
}

class IrrigationCard extends StatelessWidget {
  const IrrigationCard({super.key, required this.crop});
  final Crop crop;
  Future<Map<String, dynamic>?> _recommendation() async {
    final state = AppState.instance;
    if (state.token == null || crop.id == null) return null;
    try {
      final r = await http
          .get(
            Uri.parse(
              '$apiBase/api/irrigation/recommendation/${crop.id}?soilMoisture=${crop.moisture}',
            ),
            headers: state.headers,
          )
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    return null;
  }

  Future<int?> _enterMoisture(BuildContext context) async {
    final field = TextEditingController(
      text: crop.moisture < 0 ? '' : crop.moisture.toString(),
    );
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Soil moisture'),
        content: TextField(
          controller: field,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Moisture percentage (0–100)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(field.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<double?> _enterWater(BuildContext context) async {
    final field = TextEditingController(text: '10');
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record ${crop.name} irrigation'),
        content: TextField(
          controller: field,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Water amount (litres)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(field.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cutoffs = {
      'Tomato': 35,
      'Potato': 30,
      'Corn': 33,
      'Wheat': 28,
      'Pepper': 32,
    };
    final cutoff = cutoffs[crop.name] ?? 33;
    final fallback = crop.moisture < 0
        ? 'Enter a soil-moisture reading to get an irrigation recommendation.'
        : crop.moisture < cutoff
        ? 'Moisture is below the crop-specific guide. Check irrigation today and consider current weather conditions.'
        : 'Moisture is at or above the crop-specific guide. Recheck the soil tomorrow and check the local forecast.';
    return CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: green),
              const SizedBox(width: 8),
              Text(
                crop.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                crop.moisture < 0 ? 'No reading' : '${crop.moisture}% moisture',
                style: const TextStyle(color: muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>?>(
            future: _recommendation(),
            builder: (context, s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.data?['recommendation'] ?? fallback,
                  style: const TextStyle(
                    color: ink,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (s.data != null)
                  Text(
                    '${s.data?['explanation']} Next check: ${s.data?['nextCheck']}.',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                if (s.hasError || s.data == null)
                  const Text(
                    'Forecast is unavailable; use local weather conditions.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          Wrap(
            children: [
              TextButton(
                onPressed: () async {
                  final reading = await _enterMoisture(context);
                  if (reading != null && reading >= 0 && reading <= 100) {
                    await AppState.instance.recordSoil(crop, reading);
                  }
                },
                child: const Text('Update soil reading'),
              ),
              TextButton(
                onPressed: () async {
                  final amount = await _enterWater(context);
                  if (amount != null && amount >= 0)
                    await AppState.instance.recordIrrigation(crop, amount);
                },
                child: const Text('Record irrigation'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const PageTitle('Profile', 'Your FarmMind account'),
      const SizedBox(height: 24),
      const CircleAvatar(
        radius: 38,
        backgroundColor: Color(0xFFE3EFE6),
        child: Icon(Icons.person, color: green, size: 40),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          AppState.instance.farmer,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      const Center(
        child: Text('farmer@farmmind.app', style: TextStyle(color: muted)),
      ),
      const SizedBox(height: 24),
      const CardShell(
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.language, color: green),
              title: Text('Language'),
              subtitle: Text('English'),
            ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Icons.cloud_outlined, color: green),
              title: Text('Weather location'),
              subtitle: Text('Giza, Egypt'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () {
          AppState.instance.farmer = 'Farmer';
          AppState.instance.token = null;
          AppState.instance.farms.clear();
          AppState.instance.crops.clear();
          AppState.instance.history.clear();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        },
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
      ),
    ],
  );
}

class CropTile extends StatelessWidget {
  const CropTile({super.key, required this.crop, this.large = false});
  final Crop crop;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final ok = crop.status == 'Healthy';
    return CardShell(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ok ? const Color(0xFFE5F1E8) : const Color(0xFFFFEFE4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.spa,
                  color: ok ? green : const Color(0xFFD47A50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crop.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    Text(
                      '${crop.farm} · ${crop.date}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: ok ? const Color(0xFFE6F2E8) : const Color(0xFFFFEFE4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  crop.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: ok ? green : const Color(0xFFB85A32),
                  ),
                ),
              ),
            ],
          ),
          if (large) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddCropScreen(crop: crop),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete crop?'),
                        content: Text('Delete ${crop.name} and its history?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await AppState.instance.deleteCrop(crop);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Text(
                  'Soil moisture',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '${crop.moisture}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: crop.moisture < 0 ? 0 : crop.moisture / 100,
                minHeight: 7,
                color: crop.moisture < 35 ? Colors.orange : green,
                backgroundColor: const Color(0xFFE8ECE8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: CardShell(
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: ink)),
          ),
        ],
      ),
    ),
  );
}

class CardShell extends StatelessWidget {
  const CardShell({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: muted)),
    ],
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: ink,
          ),
        ),
      ),
      if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
    ],
  );
}

class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboard,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboard;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboard,
    decoration: inputDecoration(icon).copyWith(labelText: label),
  );
}

InputDecoration inputDecoration(IconData icon) => InputDecoration(
  prefixIcon: Icon(icon, color: muted, size: 20),
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFE5EAE5)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: green, width: 1.5),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
);
const primaryButton = ButtonStyle(
  backgroundColor: WidgetStatePropertyAll(green),
  foregroundColor: WidgetStatePropertyAll(Colors.white),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
  ),
);

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.small = false});
  final bool small;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: small
        ? MainAxisAlignment.start
        : MainAxisAlignment.center,
    children: [
      Container(
        width: small ? 34 : 48,
        height: small ? 34 : 48,
        decoration: BoxDecoration(
          color: green,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.eco, color: Colors.white, size: small ? 20 : 29),
      ),
      const SizedBox(width: 10),
      Text(
        'FarmMind',
        style: TextStyle(
          color: ink,
          fontSize: small ? 19 : 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -.5,
        ),
      ),
    ],
  );
}
