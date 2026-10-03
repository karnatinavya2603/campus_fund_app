import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase not configured yet: $error');
  }

  runApp(const CampusFundApp());
}

class CampusFundApp extends StatelessWidget {
  const CampusFundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Fund',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2457D6)),
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded, size: 72, color: Color(0xFF2457D6)),
            SizedBox(height: 16),
            Text(
              'Campus Fund',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Student funding made simple'),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final mobile = TextEditingController();
  bool _isSendingOtp = false;

  @override
  void dispose() {
    mobile.dispose();
    super.dispose();
  }

  Future<void> sendOtp() async {
    final cleanedMobile = mobile.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(cleanedMobile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit mobile number.')),
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$cleanedMobile',
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (_) => false,
            );
          } catch (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error signing in: $error')),
            );
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message ?? 'Verification failed.')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                mobile: cleanedMobile,
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not send OTP.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send OTP: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Icon(Icons.school_rounded,
                  size: 60, color: Color(0xFF2457D6)),
              const SizedBox(height: 20),
              const Text('Welcome to Campus Fund',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Enter your mobile number to continue.'),
              const SizedBox(height: 28),
              TextField(
                controller: mobile,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  prefixText: '+91  ',
                  labelText: 'Mobile number',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSendingOtp ? null : sendOtp,
                  child: Text(_isSendingOtp ? 'Sending OTP...' : 'Send OTP'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'By continuing, you agree to the Terms and Privacy Policy.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  final String mobile;
  final String verificationId;
  final int? resendToken;

  const OtpScreen({
    super.key,
    required this.mobile,
    required this.verificationId,
    this.resendToken,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final otp = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  late String _verificationId;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
  }

  @override
  void dispose() {
    otp.dispose();
    super.dispose();
  }

  Future<void> resendOtp() async {
    setState(() => _isResending = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${widget.mobile}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (_) => false,
            );
          } catch (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error signing in: $error')),
            );
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message ?? 'OTP resend failed.')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            otp.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP resent successfully.')),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
        forceResendingToken: _resendToken,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resend OTP: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> verify() async {
    final enteredOtp = otp.text.trim();
    if (enteredOtp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit OTP.')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: enteredOtp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Invalid OTP.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Icon(Icons.lock_outline, size: 58, color: Color(0xFF2457D6)),
            const SizedBox(height: 18),
            Text('OTP sent to +91 ${widget.mobile}'),
            const SizedBox(height: 24),
            TextField(
              controller: otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'Enter OTP'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isVerifying ? null : verify,
                child: Text(_isVerifying ? 'Verifying...' : 'Verify'),
              ),
            ),
            TextButton(
              onPressed: _isResending ? null : resendOtp,
              child: Text(_isResending ? 'Resending...' : 'Resend OTP'),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Fund'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.description_outlined), label: 'Application'),
          NavigationDestination(
              icon: Icon(Icons.payments_outlined), label: 'Payments'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text('Good Morning, Student 👋',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              _statusCard(context),
              const SizedBox(height: 16),
              _sectionTitle('Quick Actions'),
              Row(
                children: [
                  Expanded(
                    child: _actionCard(
                      context,
                      Icons.add_card,
                      'Apply for Funding',
                      () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FundingWizard())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionCard(
                      context,
                      Icons.track_changes,
                      'Track Application',
                      () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StatusScreen())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionTitle('Repayment'),
              Card(
                child: ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.currency_rupee)),
                  title: const Text('Total Due'),
                  subtitle: const Text('Due: 30 Oct 2026'),
                  trailing: FilledButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RepaymentScreen())),
                    child: const Text('Repay'),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _sectionTitle('Application'),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.verified_outlined),
                  title: Text('CF10245'),
                  subtitle: Text('Approved • ₹2,000'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ),
            ],
          ),
          const ApplicationsTab(),
          const PaymentsTab(),
          const ProfileTab(),
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Funding Application',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Application ID: CF10245'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                const Text('Approved',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: 0.85),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StatusScreen())),
              child: const Text('View application status'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _actionCard(
      BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 34, color: const Color(0xFF2457D6)),
              const SizedBox(height: 10),
              Text(title, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class ApplicationsTab extends StatelessWidget {
  const ApplicationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_outlined, color: Colors.green),
              title: Text('CF10245 • Approved'),
              subtitle: Text('Funding application • ₹2,000'),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Application progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...[
            ('Application Submitted', true),
            ('Documents Verified', true),
            ('Application Approved', true),
            ('Amount Disbursed', false),
          ].map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: item.$2 ? Colors.green : Colors.grey,
                ),
                title: Text(item.$1),
                subtitle: Text(item.$2 ? 'Completed' : 'Pending'),
              )),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FundingWizard())),
            icon: const Icon(Icons.add),
            label: const Text('Apply for funding'),
          ),
        ],
      ),
    );
  }
}

class PaymentsTab extends StatelessWidget {
  const PaymentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(Icons.currency_rupee)),
              title: Text('Outstanding balance'),
              subtitle: Text('Due 30 Oct 2026'),
              trailing: Text('₹2,600',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Payment history',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Card(
            child: ListTile(
              leading: Icon(Icons.receipt_long_outlined),
              title: Text('No payments yet'),
              subtitle: Text('Completed payments will appear here.'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RepaymentScreen())),
            child: const Text('View repayment options'),
          ),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          const CircleAvatar(
            radius: 42,
            child: Icon(Icons.person_outline, size: 46),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('Student',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const Center(child: Text('Campus Fund account')),
          const SizedBox(height: 24),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Personal details'),
                  subtitle: Text('Student'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.school_outlined),
                  title: Text('Education'),
                  subtitle: Text('College details not added'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('Help and support'),
                  subtitle: Text('Contact Campus Fund support'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

base class CustomPlatformFile extends PlatformFile {
  @override
  final String name;
  final int? _size;
  @override
  final Uri uri;

  CustomPlatformFile({
    required this.name,
    int? size,
    Uri? uri,
  })  : _size = size,
        uri = uri ?? Uri.parse('file:///$name');

  @override
  int? lengthSync() => _size;

  @override
  Future<int?> length() async => _size;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => Stream.empty();

  @override
  XFile get xFile => XFile(path ?? name);
}

class FundingWizard extends StatefulWidget {
  const FundingWizard({super.key});

  @override
  State<FundingWizard> createState() => _FundingWizardState();
}

class _FundingWizardState extends State<FundingWizard> {
  int step = 0;
  double amount = 2000;
  final name = TextEditingController();
  final dob = TextEditingController();
  final college = TextEditingController();
  final course = TextEditingController();
  final pan = TextEditingController();
  final Map<String, PlatformFile> _uploadedDocuments = {};

  @override
  void dispose() {
    name.dispose();
    dob.dispose();
    college.dispose();
    course.dispose();
    pan.dispose();
    super.dispose();
  }

  bool _isValidDocument(PlatformFile file) {
    final validExtensions = {'pdf', 'jpg', 'jpeg', 'png'};
    final extension = file.extension?.toLowerCase() ??
        (file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '');
    if (!validExtensions.contains(extension)) {
      return false;
    }

    const maxSizeInBytes = 5 * 1024 * 1024;
    final fileSize = file.lengthSync() ?? 0;
    return fileSize <= maxSizeInBytes;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickDocument(String title) async {
    List<PlatformFile>? pickedFiles;

    try {
      // 1. Attempt native custom filter picker
      pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
    } catch (_) {
      try {
        // 2. Fallback to native any filter picker
        pickedFiles = await FilePicker.pickFiles(
          type: FileType.any,
        );
      } catch (_) {
        pickedFiles = null;
      }
    }

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      final file = pickedFiles.first;
      if (!_isValidDocument(file)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Only PDF, JPG, JPEG, and PNG files under 5MB are allowed.',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _uploadedDocuments[title] = file;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title uploaded: ${file.name}')),
        );
      }
      return;
    }

    // 3. Fallback document file selector if native picker is unavailable or cancelled
    if (mounted) {
      _showFallbackDocumentPicker(title);
    }
  }

  void _showFallbackDocumentPicker(String title) {
    final defaultFileName = '${title.toLowerCase().replaceAll(' ', '_')}_scan.pdf';
    final customNameController = TextEditingController(text: defaultFileName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Attach $title Document',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Select or enter the $title file to attach for KYC verification:'),
              const SizedBox(height: 16),
              TextField(
                controller: customNameController,
                decoration: InputDecoration(
                  labelText: 'Document File Name',
                  hintText: 'e.g. my_${title.toLowerCase().replaceAll(' ', '_')}.pdf',
                  prefixIcon: const Icon(Icons.insert_drive_file),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: Text('Attach $title Document'),
                  onPressed: () {
                    final fileName = customNameController.text.trim();
                    if (fileName.isEmpty) return;

                    final fallbackFile = CustomPlatformFile(
                      name: fileName.contains('.') ? fileName : '$fileName.pdf',
                      size: 460 * 1024,
                    );

                    setState(() {
                      _uploadedDocuments[title] = fallbackFile;
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$title uploaded: ${fallbackFile.name}')),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDocumentPreview(String title) {
    final file = _uploadedDocuments[title];
    if (file == null) {
      return;
    }

    final fileExtension = file.extension ??
        (file.name.contains('.') ? file.name.split('.').last : 'unknown');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${file.name}'),
            const SizedBox(height: 8),
            Text('Size: ${_formatFileSize(file.lengthSync() ?? 0)}'),
            const SizedBox(height: 8),
            Text('Type: $fileExtension'),
            const SizedBox(height: 12),
            const Text('This file is ready for KYC review.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickDocument(title);
            },
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  void next() {
    if (step < 4) {
      setState(() => step++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SubmittedScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Personal', 'KYC', 'College', 'Funding', 'Review'];
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Funding')),
      body: Stepper(
        currentStep: step,
        onStepContinue: next,
        onStepCancel: () {
          if (step > 0) setState(() => step--);
        },
        controlsBuilder: (context, details) {
          return Row(
            children: [
              FilledButton(
                  onPressed: details.onStepContinue,
                  child: Text(step == 4 ? 'Submit' : 'Continue')),
              if (step > 0)
                TextButton(
                    onPressed: details.onStepCancel, child: const Text('Back')),
            ],
          );
        },
        steps: List.generate(5, (i) {
          return Step(
            title: Text(titles[i]),
            isActive: step >= i,
            content: _contentForStep(i),
          );
        }),
      ),
    );
  }

  Widget _contentForStep(int i) {
    switch (i) {
      case 0:
        return Column(children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full Name')),
          const SizedBox(height: 12),
          TextField(
              controller: dob,
              decoration: const InputDecoration(labelText: 'Date of Birth')),
        ]);
      case 1:
        return Column(children: [
          TextField(
              controller: pan,
              decoration: const InputDecoration(labelText: 'PAN Number')),
          const SizedBox(height: 12),
          _uploadTile('PAN Card'),
          _uploadTile('Aadhaar Card'),
        ]);
      case 2:
        return Column(children: [
          TextField(
              controller: college,
              decoration: const InputDecoration(labelText: 'College Name')),
          const SizedBox(height: 12),
          TextField(
              controller: course,
              decoration: const InputDecoration(labelText: 'Course')),
          const SizedBox(height: 12),
          _uploadTile('College ID'),
          _uploadTile('Fee Bill'),
        ]);
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select funding amount'),
            RadioGroup<double>(
              groupValue: amount,
              onChanged: (v) {
                if (v != null) {
                  setState(() => amount = v);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<double>(
                    value: 1000,
                    title: Text('₹1,000'),
                  ),
                  RadioListTile<double>(
                    value: 2000,
                    title: Text('₹2,000'),
                  ),
                  RadioListTile<double>(
                    value: 3000,
                    title: Text('₹3,000'),
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        final fee = amount * 0.30;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summary('Name', name.text.isEmpty ? 'Student' : name.text),
            _summary(
                'College', college.text.isEmpty ? 'Not entered' : college.text),
            _summary('Requested Amount', '₹${amount.toStringAsFixed(0)}'),
            _summary('Configured Fee/Interest', '₹${fee.toStringAsFixed(0)}'),
            _summary('Estimated Total Repayment',
                '₹${(amount + fee).toStringAsFixed(0)}'),
          ],
        );
    }
  }

  Widget _summary(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
        ],
      ),
    );
  }

  Widget _uploadTile(String title) {
    final uploadedFile = _uploadedDocuments[title];

    return Card(
      child: ListTile(
        leading: const Icon(Icons.upload_file),
        title: Text(title),
        subtitle: Text(
          uploadedFile == null
              ? 'No file selected'
              : 'Selected: ${uploadedFile.name} • ${_formatFileSize(uploadedFile.lengthSync() ?? 0)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (uploadedFile != null)
              TextButton(
                onPressed: () => _showDocumentPreview(title),
                child: const Text('Preview'),
              ),
            TextButton(
              onPressed: () => _pickDocument(title),
              child: Text(uploadedFile == null ? 'Upload' : 'Replace'),
            ),
          ],
        ),
      ),
    );
  }
}

class SubmittedScreen extends StatelessWidget {
  const SubmittedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Submitted')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 90, color: Colors.green),
              const SizedBox(height: 20),
              const Text('Application Submitted',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Application ID: CF10245'),
              const SizedBox(height: 8),
              const Text('Your application is under verification.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const DashboardScreen())),
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Application Submitted', '30 Sep 2026, 12:15 PM', true),
      ('Documents Verified', '30 Sep 2026, 2:00 PM', true),
      ('Application Approved', '30 Sep 2026, 3:30 PM', true),
      ('Amount Disbursed', 'Pending', false),
      ('Repayment', 'Pending', false),
      ('Closed', 'Pending', false),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Application Status')),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          return ListTile(
            leading: Icon(
              item.$3 ? Icons.check_circle : Icons.radio_button_unchecked,
              color: item.$3 ? Colors.green : Colors.grey,
            ),
            title: Text(item.$1),
            subtitle: Text(item.$2),
          );
        },
      ),
    );
  }
}

class RepaymentScreen extends StatelessWidget {
  const RepaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repayment')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _amountCard('Principal', '₹2,000'),
            _amountCard('Fee / Interest', '₹600'),
            _amountCard('Total Due', '₹2,600'),
            _amountCard('Due Date', '30 Oct 2026'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PaymentScreen())),
                child: const Text('REPAY NOW • ₹2,600'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountCard(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose Payment Method',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
                child: ListTile(
                    leading: const Icon(Icons.account_balance),
                    title: const Text('UPI'),
                    trailing: const Icon(Icons.chevron_right))),
            Card(
                child: ListTile(
                    leading: const Icon(Icons.credit_card),
                    title: const Text('Debit / Credit Card'),
                    trailing: const Icon(Icons.chevron_right))),
            Card(
                child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: const Text('Net Banking'),
                    trailing: const Icon(Icons.chevron_right))),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PaymentSuccessScreen())),
                child: const Text('PAY ₹2,600'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 100, color: Colors.green),
              const SizedBox(height: 20),
              const Text('Payment Successful',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Amount: ₹2,600'),
              const Text('Transaction ID: CF-TXN-20260930-001'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  (_) => false,
                ),
                child: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.check_circle, color: Colors.green),
            title: Text('Application Approved'),
            subtitle: Text('Your application CF10245 has been approved.'),
          ),
          ListTile(
            leading: Icon(Icons.payments_outlined),
            title: Text('Repayment Due'),
            subtitle: Text('Your repayment of ₹2,600 is due on 30 Oct 2026.'),
          ),
        ],
      ),
    );
  }
}
