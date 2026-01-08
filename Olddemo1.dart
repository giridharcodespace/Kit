import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// =========================================================
// 🚀 MAIN ENTRY POINT
// =========================================================
void main() {
  runApp(const PiecesApp());
}

// =========================================================
// 👤 USER SESSION (Singleton to hold login state)
// =========================================================
class UserSession {
  static int? id;
  static String? name;
  static String? email;
  static bool get isLoggedIn => id != null;

  static void clear() {
    id = null;
    name = null;
    email = null;
  }
}

// =========================================================
// 🔧 API SERVICE
// =========================================================
class ApiService {
  final String baseUrl = "http://localhost:8081"; // ⚠️ Use 10.0.2.2 for Android Emulator

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Login Failed");
    }
  }

  Future<void> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    if (response.statusCode != 200) throw Exception("Registration Failed");
  }

  // Products
  Future<List<dynamic>> getProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print("API Error: $e");
    }
    return [];
  }

  Future<List<dynamic>> searchProducts(String query) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/search?q=$query'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {}
    return [];
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products'),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception("Failed to list product");
  }

  // Bidding
  Future<List<dynamic>> getBids(String productId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/bids/$productId'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {}
    return [];
  }

  Future<void> placeBid(String productId, double amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bid'),
      body: jsonEncode({
        "productId": productId,
        "userId": UserSession.id,
        "amount": amount,
      }),
    );
    if (response.statusCode != 200) throw Exception("Bid Failed. Ensure amount is higher.");
  }

  // Orders
  Future<List<dynamic>> getOrders() async {
    if (!UserSession.isLoggedIn) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/orders/${UserSession.id}'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {}
    return [];
  }
}

// =========================================================
// 🎨 APP THEME & ROOT
// =========================================================
class PiecesApp extends StatelessWidget {
  const PiecesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pieces',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.lightBlueAccent,
        scaffoldBackgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.lightBlueAccent),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlueAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          )
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.lightBlueAccent),
          titleTextStyle: TextStyle(color: Colors.lightBlueAccent, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
      // Start at Login Page to ensure Session is set
      home: const LoginPage(),
    );
  }
}

// =========================================================
// 👤 PAGE: LOGIN
// =========================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final ApiService _api = ApiService();
  bool _isLoading = false;
  bool _isValidEmail(String email) {
  return email.contains('@') && email.contains('.');
  }

  void _doLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    // 🔴 EMAIL VALIDATION
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid email (must contain @)"),
          backgroundColor: Colors.red,
        ),
      );
      return; // ⛔ STOP login
    }

    // 🔴 PASSWORD EMPTY CHECK
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password cannot be empty"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await _api.login(email, password);

      UserSession.id = data['id'];
      UserSession.name = data['name'];
      UserSession.email = email;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Failed: check credentials")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Pieces", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent, letterSpacing: 2)),
              const SizedBox(height: 40),
              _buildTextField("Email", _emailCtrl),
              const SizedBox(height: 15),
              _buildTextField("Password", _passCtrl, obscure: true),
              const SizedBox(height: 30),
              _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(onPressed: _doLogin, child: const Text("LOGIN", style: TextStyle(fontWeight: FontWeight.bold))),
                  ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                child: const Text("New here? Register", style: TextStyle(color: Colors.white54)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// 📝 PAGE: REGISTER
// =========================================================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final ApiService _api = ApiService();

  void _doRegister() async {
    try {
      await _api.register(_nameCtrl.text, _emailCtrl.text, _passCtrl.text);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registration Successful! Please Login.")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registration Failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTextField("Full Name", _nameCtrl),
            const SizedBox(height: 15),
            _buildTextField("Email", _emailCtrl),
            const SizedBox(height: 15),
            _buildTextField("Password", _passCtrl, obscure: true),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _doRegister, child: const Text("SIGN UP")))
          ],
        ),
      ),
    );
  }
}

// Helper for TextFields
Widget _buildTextField(String hint, TextEditingController ctrl, {bool obscure = false}) {
  return TextField(
    controller: ctrl,
    obscureText: obscure,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: hint,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.grey[900],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

// =========================================================
// 🏠 MAIN SCREEN (Handles Bottom Navigation)
// =========================================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Footer: Home, Search, Seller
  final List<Widget> _pages = [
    const HomePage(),
    const SearchPage(),
    const SellProductPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.lightBlueAccent,
        unselectedItemColor: Colors.white24,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.add_business), label: "Seller"),
        ],
      ),
    );
  }
}

// =========================================================
// 📡 SHARED HEADER WIDGET (Account, Title, Menu)
// =========================================================
class SharedHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const SharedHeader({super.key, this.title = "Pieces"});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // 1. Account Icon (Left)
      leading: IconButton(
        icon: const Icon(Icons.account_circle, size: 28),
        onPressed: () {
          // Show quick account details
          showDialog(context: context, builder: (ctx) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(UserSession.name ?? "User", style: const TextStyle(color: Colors.white)),
            content: Text("Email: ${UserSession.email}\nStatus: Verified", style: const TextStyle(color: Colors.white70)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
          ));
        },
      ),
      // 2. Title (Middle)
      title: Text(title),
      centerTitle: true,
      // 3. Menu Icon (Right)
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.menu),
          color: Colors.grey[900],
          onSelected: (val) {
             if (val == 'Order') {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderPage()));
             } else if (val == 'Settings') {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
             }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'Order', child: Text("Orders", style: TextStyle(color: Colors.white))),
            const PopupMenuItem(value: 'Settings', child: Text("Settings", style: TextStyle(color: Colors.white))),
          ],
        )
      ],
    );
  }
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// =========================================================
// 🏠 PAGE 1: HOME PAGE (Carousel + Grid)
// =========================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _api = ApiService();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SharedHeader(),

        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _api.getProducts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = snapshot.data ?? [];

              return CustomScrollView(
                slivers: [
                  if (products.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: CarouselSlider(
                          options: CarouselOptions(
                            height: 220,
                            autoPlay: true,
                            enlargeCenterPage: true,
                          ),
                          items: products.take(5).map((prod) {
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductDetailsPage(data: prod),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(
                                  prod['imageUrl'],
                                  fit: BoxFit.cover,
                                  width: 1000,
                                  errorBuilder: (c, e, s) =>
                                      Container(color: Colors.grey[800]),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(left: 16, bottom: 10),
                      child: Text(
                        "Latest Collections",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.lightBlueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final p = products[index];
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailsPage(data: p),
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(15),
                                border:
                                    Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        top: Radius.circular(15),
                                      ),
                                      child: Image.network(
                                        p['imageUrl'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) =>
                                            const Icon(
                                                Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['name'],
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          "\$${p['currentPrice']}",
                                          style: const TextStyle(
                                            color:
                                                Colors.lightBlueAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: products.length,
                      ),
                    ),
                  )
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// =========================================================
// 🔍 PAGE 2: SEARCH PAGE
// =========================================================
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ApiService _api = ApiService();
  final _searchCtrl = TextEditingController();
  List<dynamic> _results = [];

  final List<String> _tags = ["Watch", "Painting", "Camera", "Pot", "Jewelry", "Coins", "Furniture"];

  void _doSearch(String q) async {
    final res = await _api.searchProducts(q);
    setState(() => _results = res);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          leading: const BackButton(),
          title: const Text("Search Artifacts"),
          backgroundColor: Colors.black,
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search name or description...",
                    prefixIcon: const Icon(Icons.search, color: Colors.lightBlueAccent),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: _doSearch,
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: _results.isEmpty
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags.map((t) => ActionChip(
                            label: Text(t),
                            backgroundColor: Colors.grey[800],
                            labelStyle: const TextStyle(color: Colors.white),
                            onPressed: () {
                              _searchCtrl.text = t;
                              _doSearch(t);
                            },
                          )).toList(),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final item = _results[i];
                            return ListTile(
                              leading: Image.network(
                                item['imageUrl'],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                              title: Text(item['name'],
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                "\$${item['currentPrice']} • ${item['description']}",
                                maxLines: 1,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            );
                          },
                        ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================================
// 📄 PAGE 3: PRODUCT DETAILS
// =========================================================
class ProductDetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;
  const ProductDetailsPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Parse Dates
    final endTime = DateTime.parse(data['endTime']);
    final now = DateTime.now();
    final isLive = now.isBefore(endTime);

    return Scaffold(
      appBar: const SharedHeader(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zoomable Image
            Container(
              height: 350,
              color: Colors.grey[900],
              child: InteractiveViewer(
                child: Image.network(data['imageUrl'], width: double.infinity, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Center(child: Icon(Icons.broken_image, size: 50))),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Price
                  Text(data['name'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("\$${data['currentPrice']}", style: const TextStyle(fontSize: 20, color: Colors.lightBlueAccent)),
                  const SizedBox(height: 15),

                  // Seller Info
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.store, color: Colors.lightBlueAccent),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(data['sellerName'] ?? "Unknown Seller", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Row(children: [
                             const Icon(Icons.star, size: 14, color: Colors.amber),
                             Text(" ${data['sellerRating']}", style: const TextStyle(color: Colors.white70))
                          ])
                        ])
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(data['description'], style: const TextStyle(color: Colors.white70, height: 1.5)),
                  const SizedBox(height: 30),

                  // Auction Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isLive ? () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => BiddingPage(data: data)));
                      } : null, // Disable if auction ended
                      child: Text(isLive ? "JOIN AUCTION" : "AUCTION ENDED", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Times
                  _buildTimeRow("Ends:", endTime.toString().substring(0, 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRow(String label, String time) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white54)),
      Text(time, style: const TextStyle(color: Colors.lightBlueAccent))
    ]);
  }
}

// =========================================================
// 💰 PAGE 4: BIDDING PAGE (Live Logic)
// =========================================================
class BiddingPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const BiddingPage({super.key, required this.data});
  @override
  State<BiddingPage> createState() => _BiddingPageState();
}

class _BiddingPageState extends State<BiddingPage> {
  final ApiService _api = ApiService();
  final _bidCtrl = TextEditingController();
  List<dynamic> _bids = [];
  double _currentHighest = 0.0;

  @override
  void initState() {
    super.initState();
    _currentHighest =
        double.parse(widget.data['currentPrice'].toString());

    _loadBids(); // load only once
  }


  Future<void> _loadBids() async {
    final bids =
        await _api.getBids(widget.data['id'].toString());

    if (!mounted) return;

    setState(() {
      _bids = bids;

      if (_bids.isNotEmpty) {
        _currentHighest =
            double.parse(_bids.first['amount'].toString());
      }
    });
  }


  void _submitBid() async {
    if (_bidCtrl.text.isEmpty) return;
    double amount = double.tryParse(_bidCtrl.text) ?? 0.0;

    // Logic: Must be higher than current highest
    if (amount <= _currentHighest) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bid must be higher than current price!"), backgroundColor: Colors.red));
       return;
    }

    try {
      await _api.placeBid(widget.data['id'].toString(), amount);

    _bidCtrl.clear();

    // refresh ONLY after successful bid
    await _loadBids();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Bid placed successfully")),
    );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bid Placed!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SharedHeader(title: "Live Auction"),
      body: Column(
        children: [
          // Small Product Info
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.grey[900],
            child: Row(
              children: [
                Image.network(widget.data['imageUrl'], width: 60, height: 60, fit: BoxFit.cover),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.data['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text("Current High: \$${_currentHighest}", style: const TextStyle(color: Colors.lightBlueAccent)),
                  ],
                ))
              ],
            ),
          ),

        Expanded(
          child: _bids.isEmpty
            ? const Center(
                child: Text(
                  "No bids yet. Be the first bidder!",
                  style: TextStyle(color: Colors.white54),
                ),
              )
            : ListView.builder(
                itemCount: _bids.length,
                itemBuilder: (ctx, i) {
                  final b = _bids[i];
                  return ListTile(
                    leading:
                        const Icon(Icons.gavel, color: Colors.white24),
                    title: Text(
                      "\$${b['amount']}",
                      style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      "${b['userName']} • ${b['time']}",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
          ),


          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bidCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter amount > $_currentHighest",
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: _submitBid, child: const Text("BID"))
              ],
            ),
          )
        ],
      ),
    );
  }
}

// =========================================================
// 🏷️ PAGE 5: SELLER PAGE (New Tab)
// =========================================================
class SellProductPage extends StatefulWidget {
  const SellProductPage({super.key});
  @override
  State<SellProductPage> createState() => _SellProductPageState();
}

class _SellProductPageState extends State<SellProductPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  final _imgCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _durCtrl = TextEditingController();
  final ApiService _api = ApiService();

  void _submit() async {
    try {
      await _api.addProduct({
        "sellerId": UserSession.id,
        "name": _nameCtrl.text,
        "description": _descCtrl.text,
        "category": _catCtrl.text,
        "imageUrl": _imgCtrl.text,
        "startPrice": double.parse(_priceCtrl.text),
        "duration": int.parse(_durCtrl.text) // Duration in hours
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Listed!")));
      _nameCtrl.clear(); _descCtrl.clear(); _imgCtrl.clear(); _priceCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to list product")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SharedHeader(title: "Sell Artifact"),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTextField("Product Name", _nameCtrl),
                const SizedBox(height: 10),
                _buildTextField("Category (e.g., Pot, Watch)", _catCtrl),
                const SizedBox(height: 10),
                _buildTextField("Description", _descCtrl),
                const SizedBox(height: 10),
                _buildTextField("Image URL", _imgCtrl),
                const SizedBox(height: 10),
                _buildTextField("Start Price (\$)", _priceCtrl),
                const SizedBox(height: 10),
                _buildTextField("Duration (Hours)", _durCtrl),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text("START AUCTION"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================================
// 📦 PAGE 6: ORDER PAGE
// =========================================================
class OrderPage extends StatelessWidget {
  const OrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SharedHeader(title: "My Orders"),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService().getOrders(),
        builder: (context, snapshot) {
           final orders = snapshot.data ?? [];
           if (orders.isEmpty) {
             return const Center(child: Text("No Orders (You haven't won any auctions yet)", style: TextStyle(color: Colors.white54)));
           }
           return ListView.builder(
             itemCount: orders.length,
             itemBuilder: (ctx, i) {
               final o = orders[i];
               return ListTile(
                 leading: Image.network(o['imageUrl'], width: 50, height: 50, fit: BoxFit.cover),
                 title: Text(o['name'], style: const TextStyle(color: Colors.white)),
                 subtitle: Text("Won for \$${o['price']}", style: const TextStyle(color: Colors.lightBlueAccent)),
               );
             },
           );
        },
      ),
    );
  }
}

// =========================================================
// ⚙️ PAGE 7: SETTINGS PAGE
// =========================================================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SharedHeader(title: "Settings"),
      body: ListView(
        children: [
          _tile("Notifications", Icons.notifications),
          _tile("Help Center", Icons.help),
          _tile("Privacy Policy", Icons.lock),
          _tile("About", Icons.info),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Log Out", style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              UserSession.clear();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
            },
          )
        ],
      ),
    );
  }

  Widget _tile(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.lightBlueAccent),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
    );
  }
}
