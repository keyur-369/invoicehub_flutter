import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:invoicehub/models/profile.dart';
import 'package:invoicehub/providers/auth_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:invoicehub/widgets/signature_pad_dialog.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _gstController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  
  File? _logoFile;
  File? _signatureFile;
  bool _isLoading = false;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final profile = ref.watch(profileProvider).value;
      if (profile != null) {
        _shopNameController.text = profile.shopName ?? '';
        _ownerNameController.text = profile.ownerName ?? '';
        _gstController.text = profile.gstNumber ?? '';
        _mobileController.text = profile.mobile ?? '';
        _addressController.text = profile.address ?? '';
        _cityController.text = profile.city ?? '';
      }
      _isInit = false;
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _logoFile = File(pickedFile.path));
    }
  }

  Future<void> _pickSignature() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _signatureFile = File(pickedFile.path));
    }
  }
  Future<void> _drawSignature() async {
    final Uint8List? signatureData = await showDialog<Uint8List>(
      context: context,
      builder: (context) => const SignaturePadDialog(),
    );

    if (signatureData != null) {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(signatureData);
      setState(() => _signatureFile = file);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;
      
      final currentProfile = ref.read(profileProvider).value;

      String? logoUrl = currentProfile?.logoUrl;
      if (_logoFile != null) {
        logoUrl = await ref.read(profileServiceProvider).uploadLogo(
          currentProfile?.id ?? user.id,
          _logoFile!,
        );
      }

      String? signatureUrl = currentProfile?.signatureUrl;
      if (_signatureFile != null) {
        signatureUrl = await ref.read(profileServiceProvider).uploadSignature(
          currentProfile?.id ?? user.id,
          _signatureFile!,
        );
      }

      final updatedProfile = Profile(
        id: currentProfile?.id ?? '', // Upsert will handle this
        userId: user.id,
        role: currentProfile?.role ?? 'shop_owner',
        shopName: _shopNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        gstNumber: _gstController.text.trim(),
        mobile: _mobileController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        logoUrl: logoUrl,
        signatureUrl: signatureUrl,
        isProfileCompleted: true,
        createdAt: currentProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(profileProvider.notifier).saveProfile(updatedProfile);
      Fluttertoast.showToast(msg: 'Profile completed successfully!');
      if (mounted) context.go('/dashboard');
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Business Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    backgroundImage: _logoFile != null 
                        ? FileImage(_logoFile!) 
                        : (profile?.logoUrl != null ? NetworkImage(profile!.logoUrl!) : null) as ImageProvider?,
                    child: _logoFile == null && profile?.logoUrl == null
                        ? const Icon(Icons.add_a_photo, size: 40, color: Colors.blue)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload Shop Logo',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _shopNameController,
                decoration: const InputDecoration(labelText: 'Shop Name', prefixIcon: Icon(Icons.store)),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ownerNameController,
                decoration: const InputDecoration(labelText: 'Owner Name', prefixIcon: Icon(Icons.person)),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gstController,
                decoration: const InputDecoration(labelText: 'GST Number (Optional)', prefixIcon: Icon(Icons.receipt)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on)),
                maxLines: 2,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city)),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              const Text(
                'Digital Signature',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickSignature,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        ),
                        child: _signatureFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_signatureFile!, fit: BoxFit.contain),
                              )
                            : (profile?.signatureUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(profile!.signatureUrl!, fit: BoxFit.contain),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit_note, size: 40, color: Colors.grey),
                                      SizedBox(height: 4),
                                      Text('Upload Image', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  )),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: _drawSignature,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.gesture, size: 40, color: Colors.blue),
                            SizedBox(height: 4),
                            Text('Draw Signature', style: TextStyle(color: Colors.blue, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading ? const CircularProgressIndicator() : const Text('Save & Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
