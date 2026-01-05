import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LicenseStatus { trial, licensed, expired }

class LicenseManager {
  static const String _firstRunKey = 'app_first_run';
  static const String _licenseKey = 'app_license';
  static const int trialDays = 5;

  static Future<LicenseStatus> checkLicense() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_licenseKey) != null) return LicenseStatus.licensed;
    final firstRun = prefs.getString(_firstRunKey);
    if (firstRun == null) {
      await prefs.setString(_firstRunKey, DateTime.now().toIso8601String());
      return LicenseStatus.trial;
    }
    final startDate = DateTime.parse(firstRun);
    final daysUsed = DateTime.now().difference(startDate).inDays;
    return daysUsed < trialDays ? LicenseStatus.trial : LicenseStatus.expired;
  }

  static Future<int> getRemainingDays() async {
    final prefs = await SharedPreferences.getInstance();
    final firstRun = prefs.getString(_firstRunKey);
    if (firstRun == null) return trialDays;
    final startDate = DateTime.parse(firstRun);
    final daysUsed = DateTime.now().difference(startDate).inDays;
    return (trialDays - daysUsed).clamp(0, trialDays);
  }

  static Future<bool> activate(String key) async {
    final cleaned = key.trim().toUpperCase();
    final regex = RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}');
    if (regex.hasMatch(cleaned) && cleaned.length == 19) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseKey, cleaned);
      return true;
    }
    return false;
  }
}

class TrialBanner extends StatelessWidget {
  final int daysRemaining;
  const TrialBanner({super.key, required this.daysRemaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: daysRemaining <= 2 ? Colors.red : Colors.orange,
      child: Text(
        'Teste: ' + daysRemaining.toString() + ' dias restantes',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class LicenseExpiredScreen extends StatefulWidget {
  const LicenseExpiredScreen({super.key});
  @override
  State<LicenseExpiredScreen> createState() => _LicenseExpiredScreenState();
}

class _LicenseExpiredScreenState extends State<LicenseExpiredScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _activate() async {
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 500));
    final ok = await LicenseManager.activate(_ctrl.text);
    if (ok && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RestartApp()));
    } else if (mounted) {
      setState(() { _error = 'Chave inválida'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.red.shade800, Colors.red.shade600], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 80, color: Colors.white),
                const SizedBox(height: 24),
                const Text('Período de Teste Encerrado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 32),
                TextField(controller: _ctrl, decoration: InputDecoration(labelText: 'Chave de Licença', hintText: 'XXXX-XXXX-XXXX-XXXX', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), errorText: _error), textCapitalization: TextCapitalization.characters, maxLength: 19),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _activate, style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.green), child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Ativar', style: TextStyle(fontSize: 18, color: Colors.white)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RestartApp extends StatelessWidget {
  const RestartApp({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([LicenseManager.checkLicense(), LicenseManager.getRemainingDays()]),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return MyApp(licenseStatus: snap.data![0] as LicenseStatus, remainingDays: snap.data![1] as int);
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = await LicenseManager.checkLicense();
  final days = await LicenseManager.getRemainingDays();
  runApp(MyApp(licenseStatus: status, remainingDays: days));
}

class MyApp extends StatelessWidget {
  final LicenseStatus licenseStatus;
  final int remainingDays;
  const MyApp({super.key, required this.licenseStatus, required this.remainingDays});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
      home: licenseStatus == LicenseStatus.expired ? const LicenseExpiredScreen() : HomeScreen(licenseStatus: licenseStatus, remainingDays: remainingDays),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final LicenseStatus licenseStatus;
  final int remainingDays;
  const HomeScreen({super.key, required this.licenseStatus, required this.remainingDays});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, dynamic>> marmitas = [
    {'nome': 'Frango Grelhado', 'preco': 18.90, 'calorias': 350, 'imagem': Icons.restaurant},
    {'nome': 'Salmão com Legumes', 'preco': 24.90, 'calorias': 420, 'imagem': Icons.set_meal},
    {'nome': 'Carne Magra', 'preco': 22.50, 'calorias': 380, 'imagem': Icons.lunch_dining},
    {'nome': 'Peixe Assado', 'preco': 20.90, 'calorias': 310, 'imagem': Icons.dining},
  ];

  List<Map<String, dynamic>> carrinho = [];
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marmita Fit'),
        centerTitle: true,
        backgroundColor: Colors.green.shade400,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => _showCarrinho(),
              ),
              if (carrinho.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.red,
                    child: Text(
                      carrinho.length.toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.licenseStatus == LicenseStatus.trial) TrialBanner(daysRemaining: widget.remainingDays),
          Expanded(child: _buildContent()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => setState(() => selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoritos'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (selectedIndex == 0) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Marmitas Fit Disponíveis',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...marmitas.map((marmita) => Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.green.shade100,
                    child: Icon(marmita['imagem'], size: 30, color: Colors.green),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(marmita['nome'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('R\$ ${marmita['preco'].toStringAsFixed(2)}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                        Text('${marmita['calorias']} cal', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _adicionarCarrinho(marmita),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Adicionar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          )).toList(),
        ],
      );
    }
    return const Center(child: Text('Em breve'));
  }

  void _adicionarCarrinho(Map<String, dynamic> marmita) {
    setState(() {
      carrinho.add(marmita);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${marmita['nome']} adicionado ao carrinho')),
    );
  }

  void _showCarrinho() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Carrinho', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: carrinho.isEmpty
                  ? const Center(child: Text('Carrinho vazio'))
                  : ListView.builder(
                      itemCount: carrinho.length,
                      itemBuilder: (context, index) {
                        final item = carrinho[index];
                        return ListTile(
                          leading: Icon(item['imagem']),
                          title: Text(item['nome']),
                          subtitle: Text('R\$ ${item['preco'].toStringAsFixed(2)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => setState(() => carrinho.removeAt(index)),
                          ),
                        );
                      },
                    ),
            ),
            if (carrinho.isNotEmpty)
              Column(
                children: [
                  Text('Total: R\$ ${carrinho.fold(0.0, (sum, item) => sum + item['preco']).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pedido realizado com sucesso!')),
                        );
                        setState(() => carrinho.clear());
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Finalizar Pedido', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}