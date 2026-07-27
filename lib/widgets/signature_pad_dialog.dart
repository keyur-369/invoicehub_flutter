import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignaturePadDialog extends StatefulWidget {
  const SignaturePadDialog({super.key});

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Draw Your Signature'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Signature(
              controller: _controller,
              height: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Draw inside the box',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _controller.clear(),
          child: const Text('Clear'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_controller.isEmpty) return;
            final Uint8List? data = await _controller.toPngBytes();
            if (context.mounted) Navigator.pop(context, data);
          },
          child: const Text('Save Signature'),
        ),
      ],
    );
  }
}
