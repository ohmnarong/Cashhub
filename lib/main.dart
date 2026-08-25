import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CashHub',
      theme: ThemeData(
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/shops': (context) => const ShopsScreen(),
        '/cashback': (context) => const CashbackScreen(),
        '/referral': (context) => const ReferralScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.hasData ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final refCode = TextEditingController();
  bool isReg = false;

  Future<void> submit() async {
    try {
      if (isReg) {
        UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(), password: pass.text.trim(),
        );
        String uid = userCred.user!.uid;
        String myCode = uid.substring(0, 8).toUpperCase();

        String? referrerId;
        if (refCode.text.trim().isNotEmpty) {
          final refUser = await FirebaseFirestore.instance
              .collection('users')
              .where('referralCode', isEqualTo: refCode.text.trim().toUpperCase())
              .limit(1)
              .get();
          if (refUser.docs.isNotEmpty) referrerId = refUser.docs.first.id;
        }

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': email.text.trim(),
          'balance': 0.0,
          'totalCashback': 0.0,
          'referralCode': myCode,
          'referrerId': referrerId,
          'referralCount': 0,
          'referralEarnings': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (referrerId != null) {
          await FirebaseFirestore.instance.collection('users').doc(referrerId).update({
            'referralCount': FieldValue.increment(1),
          });
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(), password: pass.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.savings, size: 64, color: Colors.green),
                const SizedBox(height: 12),
                Text('CashHub', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green[700])),
                const Text('ช้อปปิ้ง คืนเงิน แนะนำเพื่อนได้คอม — ฟรี!', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                TextField(controller: email, keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'อีเมล', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: pass, obscureText: true,
                    decoration: const InputDecoration(labelText: 'รหัสผ่าน', border: OutlineInputBorder())),
                if (isReg) ...[
                  const SizedBox(height: 16),
                  TextField(controller: refCode,
                      decoration: const InputDecoration(labelText: 'รหัสแนะนำ (ถ้ามี)', border: OutlineInputBorder())),
                ],
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.green),
                  child: Text(isReg ? 'ลงทะเบียนฟรี' : 'เข้าสู่ระบบ', style: TextStyle(fontSize: 16, color: Colors.white)),
                )),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => isReg = !isReg),
                  child: Text(isReg ? 'มีบัญชีแล้ว? เข้าสู่ระบบ' : 'ยังไม่มีบัญชี? ลงทะเบียนฟรี'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  Map<String, dynamic>? userData;
  final currency = NumberFormat('#,##0.00', 'th_TH');
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) setState(() => userData = doc.data());
  }

  Widget _page(int index) {
    switch (index) {
      case 0: return _homePage();
      case 1: return const ShopsScreen();
      case 2: return const CashbackScreen();
      case 3: return const ReferralScreen();
      default: return _homePage();
    }
  }

  Widget _homePage() {
    if (userData == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 6,
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Text('ยอดคงเหลือ', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('฿ ${currency.format(userData!['balance'])}',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniStat('คืนเงินรวม', '฿${currency.format(userData!['totalCashback'])}'),
                      _miniStat('แนะนำได้', '฿${currency.format(userData!['referralEarnings'])}'),
                      _miniStat('สมาชิก', '${userData!['referralCount']} คน'),
                    ],
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            const Text('ร้านค้าแนะนำ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView(scrollDirection: Axis.horizontal, children: const [
                _ShopCard(name: 'Shopee', cashback: '3-8%', icon: Icons.shopping_bag),
                _ShopCard(name: 'Lazada', cashback: '4-10%', icon: Icons.storefront),
                _ShopCard(name: 'TikTok Shop', cashback: '5-12%', icon: Icons.video_collection),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) => Column(
    children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold)), Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CashHub 🆓'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: _page(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าแรก'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: 'ร้านค้า'),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'คืนเงิน'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'แนะนำ'),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final String name, cashback;
  final IconData icon;
  const _ShopCard({required this.name, required this.cashback, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: Colors.green),
                const SizedBox(height: 8),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('คืนเงิน $cashback', style: TextStyle(color: Colors.green[700], fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShopsScreen extends StatelessWidget {
  const ShopsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ร้านค้าทั้งหมด')),
      body: ListView(padding: const EdgeInsets.all(16), children: const [
        _ShopListItem(name: 'Shopee', cashback: '3% - 8%', logo: Icons.shopping_bag),
        _ShopListItem(name: 'Lazada', cashback: '4% - 10%', logo: Icons.storefront),
        _ShopListItem(name: 'TikTok Shop', cashback: '5% - 12%', logo: Icons.video_collection),
      ]),
    );
  }
}

class _ShopListItem extends StatelessWidget {
  final String name, cashback;
  final IconData logo;
  const _ShopListItem({required this.name, required this.cashback, required this.logo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.green[100], child: Icon(logo, color: Colors.green)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('คืนเงิน: $cashback'),
        trailing: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('ช้อปเลย'),
        ),
      ),
    );
  }
}

class CashbackScreen extends StatelessWidget {
  const CashbackScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติคืนเงิน')),
      body: const Center(child: Text('ประวัติรายการคืนเงินจะแสดงที่นี่', style: TextStyle(fontSize: 16))),
    );
  }
}

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  Map<String, dynamic>? userData;
  final currency = NumberFormat('#,##0.00', 'th_TH');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) setState(() => userData = doc.data());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แนะนำเพื่อน')),
      body: userData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        const Text('รหัสแนะนำของคุณ', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        SelectableText(userData!['referralCode'], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Share.share('👇 ลงทะเบียน CashHub ฟรี! รหัสของฉัน: ${userData!['referralCode']}\nช้อปปิ้งคืนเงินทุกครั้ง! 🎉');
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('แชร์ให้เพื่อน'),
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statBox('สมาชิก', '${userData!['referralCount']} คน'),
                            _statBox('ค่าคอมรวม', '฿${currency.format(userData!['referralEarnings'])}'),
                          ],
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        '📌 วิธีรับค่าคอมมิชชั่น:\n'
                        '1. แชร์รหัสแนะนำให้เพื่อนสมัคร (ฟรี!)\n'
                        '2. เพื่อนช้อปปิ้งผ่านแอป → ได้คืนเงิน\n'
                        '3. คุณได้รับค่าคอม 5% จากยอดคืนเงินของเพื่อน\n'
                        '✅ ไม่จำกัดจำนวนเพื่อน!\n'
                        '✅ ไม่ต้องจ่ายเงินก่อน!',
                        style: TextStyle(height: 1.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statBox(String label, String value) => Column(
    children: [Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text(label)],
  );
}
