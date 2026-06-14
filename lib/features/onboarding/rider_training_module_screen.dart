import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../core/widgets/rider_glow_button.dart';

class RiderTrainingModuleScreen extends StatefulWidget {
  const RiderTrainingModuleScreen({super.key, this.embeddedMode = false});
  final bool embeddedMode;

  @override
  State<RiderTrainingModuleScreen> createState() =>
      _RiderTrainingModuleScreenState();
}

class _RiderTrainingModuleScreenState extends State<RiderTrainingModuleScreen> {
  int _currentModule = 0;
  bool _quizMode = false;

  final List<Map<String, dynamic>> _modules = [
    {
      'title': 'Delivery SOP',
      'content':
          'Follow the standard operating procedure for every delivery. Always check the item details, ensure the package is sealed, and confirm the customer address before leaving the hub.',
      'icon': Icons.local_shipping,
    },
    {
      'title': 'TBYB SOP',
      'content':
          'Try Before You Buy (TBYB) allows customers to inspect items before paying. Wait patiently while the customer tries the item. Do not leave the premises until the customer returns unselected items.',
      'icon': Icons.checkroom,
    },
    {
      'title': 'Customer Handling',
      'content':
          'Maintain a polite and professional demeanor at all times. Greet the customer, verify their identity politely, and handle packages with care.',
      'icon': Icons.support_agent,
    },
    {
      'title': 'Return Process',
      'content':
          'For returns, inspect the item for damages or missing tags. Ensure the return matches the app description before accepting it. Hand over a receipt if required.',
      'icon': Icons.assignment_return,
    },
    {
      'title': 'Fraud Prevention',
      'content':
          'Be vigilant against common scams. Verify OTPs securely, never share your own OTP, and report any suspicious behavior directly to support.',
      'icon': Icons.security,
    },
  ];

  final List<Map<String, dynamic>> _questions = [
    {
      'q': 'What should you do during a TBYB order?',
      'options': [
        'Drop the package and leave',
        'Wait while the customer tries the item',
        'Ask the customer to pay first',
      ],
      'answer': 1,
    },
    {
      'q': 'How should you handle an unsealed package at the hub?',
      'options': [
        'Deliver it anyway',
        'Tape it yourself',
        'Report it to the hub manager',
      ],
      'answer': 2,
    },
    {
      'q': 'What is the standard procedure for customer handling?',
      'options': [
        'Be polite and professional',
        'Argue if they take too long',
        'Ignore their questions',
      ],
      'answer': 0,
    },
    {
      'q': 'Before accepting a return from a customer, you must:',
      'options': [
        'Inspect for damages and tags',
        'Accept it blindly',
        'Tell them to return it later',
      ],
      'answer': 0,
    },
    {
      'q': 'To prevent fraud, you should:',
      'options': [
        'Share your OTP if asked',
        'Verify OTPs securely',
        'Skip OTP verification if in a hurry',
      ],
      'answer': 1,
    },
  ];

  final Map<int, int> _answers = {};
  bool _submitting = false;

  void _nextModule() {
    if (_currentModule < _modules.length - 1) {
      setState(() {
        _currentModule++;
      });
    } else {
      setState(() {
        _quizMode = true;
      });
    }
  }

  Future<void> _submitQuiz() async {
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i]['answer']) {
        score++;
      }
    }

    double percentage = (score / _questions.length) * 100;

    if (percentage >= 80) {
      setState(() => _submitting = true);
      try {
        final auth = context.read<AuthProvider>();
        final userId = auth.user?.id;
        if (userId != null) {
          // Update training status
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
                'training.status': 'completed',
                'training.completedAt': FieldValue.serverTimestamp(),
              });

          // Notify admin
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': 'admin',
            'title': 'Rider Training Completed',
            'body':
                'Rider $userId has successfully completed the training module.',
            'createdAt': FieldValue.serverTimestamp(),
            'type': 'training_completion',
          });
        }

        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF141414),
            title: const Text(
              'Congratulations!',
              style: TextStyle(color: Color(0xFFF5E7C1)),
            ),
            content: Text(
              'You passed the quiz with $score/${_questions.length} correct answers.',
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.pop(); // Go back to dashboard or next step
                },
                child: const Text(
                  'Continue',
                  style: TextStyle(color: Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    } else {
      // Failed
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text(
            'Quiz Failed',
            style: TextStyle(color: Colors.redAccent),
          ),
          content: Text(
            'You scored $score/${_questions.length}. A minimum of 80% is required to pass. Please review the modules and try again.',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _quizMode = false;
                  _currentModule = 0;
                  _answers.clear();
                });
              },
              child: const Text(
                'Retry Training',
                style: TextStyle(color: Color(0xFF4F46E5)),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildModuleContent() {
    final mod = _modules[_currentModule];
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(mod['icon'], size: 40, color: const Color(0xFF6366F1)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    mod['title'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF5E7C1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              mod['content'],
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Color(0xFFA1A1AA),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: RiderGlowButton(
                label: _currentModule < _modules.length - 1
                    ? 'Next Module'
                    : 'Start Quiz',
                onPressed: _nextModule,
              ),
            ),
          ],
        )
        .animate(key: ValueKey(_currentModule))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }

  Widget _buildQuizContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Training Assessment',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF5E7C1),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final q = _questions[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${q['q']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate((q['options'] as List).length, (optIndex) {
                      final option = q['options'][optIndex];
                      // ignore: deprecated_member_use
                      return RadioListTile<int>(
                        title: Text(
                          option,
                          style: const TextStyle(color: Color(0xFFD1D5DB)),
                        ),
                        value: optIndex,
                        // ignore: deprecated_member_use
                        groupValue: _answers[index],
                        // ignore: deprecated_member_use
                        onChanged: (val) {
                          setState(() {
                            _answers[index] = val!;
                          });
                        },
                        activeColor: const Color(0xFF6366F1),
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: RiderGlowButton(
            label: _submitting ? 'Submitting...' : 'Submit Answers',
            onPressed: (_answers.length == _questions.length && !_submitting)
                ? _submitQuiz
                : null,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF222222)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: _quizMode ? _buildQuizContent() : _buildModuleContent(),
        ),
      ),
    );

    if (widget.embeddedMode) {
      return body;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text(
          'Rider Training',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: body,
    );
  }
}
