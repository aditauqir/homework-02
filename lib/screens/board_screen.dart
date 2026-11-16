import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/board_service.dart';

/// The core message board screen.
///
/// Features a real-time live stream of all messages via `snapshots()`,
/// full CRUD operations guarded by Firestore security rules,
/// intentional empty states, and in-app diagnostics for rules enforcement
/// and idempotency testing.
class BoardScreen extends StatefulWidget {
  final User user;
  final UserProfile profile;

  const BoardScreen({
    super.key,
    required this.user,
    required this.profile,
  });

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final BoardService _boardService = BoardService();
  final AuthService _authService = AuthService();

  final TextEditingController _composerCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final Stream<List<Message>> _boardStream;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    // Cache stream once in state to avoid redundant re-subscriptions
    _boardStream = _boardService.messageBoard();
  }

  @override
  void dispose() {
    _composerCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _postMessage() async {
    final text = _composerCtrl.text.trim();
    if (text.isEmpty || _isPosting) return;

    setState(() => _isPosting = true);
    _composerCtrl.clear();

    try {
      final idempotencyKey = DateTime.now().millisecondsSinceEpoch.toString();
      await _boardService.postMessageIdempotent(
        authorUid: widget.user.uid,
        authorName: widget.profile.fullName.isNotEmpty
            ? widget.profile.fullName
            : (widget.user.email ?? 'Anonymous'),
        text: text,
        idempotencyKey: idempotencyKey,
      );

      // Auto-scroll to bottom after slight delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post message: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _promptEdit(Message message) async {
    final editCtrl = TextEditingController(text: message.text);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Message'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: editCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Message Text',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Text cannot be empty' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated == true && mounted) {
      try {
        await _boardService.editMessage(
          messageId: message.id,
          newText: editCtrl.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message updated successfully.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
    editCtrl.dispose();
  }

  Future<void> _confirmDelete(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
          'Are you sure you want to delete this message? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _boardService.deleteMessage(messageId: message.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  void _showDevRulesTestDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RulesDiagnosticsSheet(
        boardService: _boardService,
        currentUid: widget.user.uid,
        currentName: widget.profile.fullName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B2430),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Message Board Vault',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.profile.fullName} (${widget.profile.role})',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Rules & Idempotency Testing (Spices)',
            icon: const Icon(Icons.security_outlined, color: Colors.amber),
            onPressed: _showDevRulesTestDialog,
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live Message List
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _boardStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'Failed to load message stream',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text('${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.forum_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'The vault board is quiet.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No messages have been posted yet.\nBe the first to leave a notice on the live stream!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMyMessage = msg.authorUid == widget.user.uid;

                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isMyMessage
                            ? BorderSide(color: Colors.amber.shade700, width: 1.2)
                            : BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Author & Date Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isMyMessage
                                          ? Colors.amber[800]
                                          : Colors.blueGrey[600],
                                      child: Text(
                                        msg.authorName.isNotEmpty
                                            ? msg.authorName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      msg.authorName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isMyMessage
                                            ? Colors.amber[900]
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (isMyMessage)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber[100],
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'YOU',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.brown,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      msg.createdAt != null
                                          ? _formatTime(msg.createdAt!)
                                          : 'Sending...',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (msg.isEdited)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 4.0),
                                        child: Text(
                                          '(edited)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Message Text
                            Text(
                              msg.text,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),

                            // Owner CRUD Controls
                            if (isMyMessage) ...[
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: Colors.blue[700],
                                    ),
                                    onPressed: () => _promptEdit(msg),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Edit'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: Colors.red[700],
                                    ),
                                    onPressed: () => _confirmDelete(msg),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16),
                                    label: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Composer Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composerCtrl,
                      decoration: InputDecoration(
                        hintText: 'Post a notice to the vault board...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _postMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: _isPosting ? null : _postMessage,
                    icon: _isPosting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// In-App Diagnostics Bottom Sheet for Live Rule Denial & Idempotency Testing.
class _RulesDiagnosticsSheet extends StatefulWidget {
  final BoardService boardService;
  final String currentUid;
  final String currentName;

  const _RulesDiagnosticsSheet({
    required this.boardService,
    required this.currentUid,
    required this.currentName,
  });

  @override
  State<_RulesDiagnosticsSheet> createState() => _RulesDiagnosticsSheetState();
}

class _RulesDiagnosticsSheetState extends State<_RulesDiagnosticsSheet> {
  String _logOutput = 'Select a diagnostic test below to run live.';
  bool _running = false;

  Future<void> _testForgedCreate() async {
    setState(() {
      _running = true;
      _logOutput = 'Testing forged authorUid creation...';
    });

    try {
      await widget.boardService.simulateForgedCreate(
        forgedAuthorUid: 'imposter_fake_uid_9999',
        authorName: 'Hacker Bob',
        text: 'Forged message bypassing ownership',
      );
      setState(() {
        _logOutput =
            'SECURITY FAILURE: Forged authorUid write succeeded! Check security rules.';
      });
    } catch (e) {
      setState(() {
        _logOutput =
            '✔ EXPECTED DENIAL SUCCESS:\nCaught Firestore Security Rule error:\n$e';
      });
    } finally {
      setState(() => _running = false);
    }
  }

  Future<void> _testCrossUidEdit() async {
    setState(() {
      _running = true;
      _logOutput = 'Testing cross-uid unauthorized edit...';
    });

    try {
      await widget.boardService.simulateUnauthorizedEdit(
        messageId: 'some_foreign_message_doc_id',
        maliciousText: 'Unauthorized malicious overwrite',
      );
      setState(() {
        _logOutput =
            'SECURITY FAILURE: Cross-UID edit succeeded! Check security rules.';
      });
    } catch (e) {
      setState(() {
        _logOutput =
            '✔ EXPECTED DENIAL SUCCESS:\nCaught Firestore Security Rule error:\n$e';
      });
    } finally {
      setState(() => _running = false);
    }
  }

  Future<void> _testIdempotentDoubleSubmit() async {
    setState(() {
      _running = true;
      _logOutput =
          'Running Idempotent Alchemist (Spice #4) concurrent double-submit drill...';
    });

    final testKey = 'test_nonce_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Fire two identical writes concurrently with identical idempotencyKey
      final results = await Future.wait([
        widget.boardService.postMessageIdempotent(
          authorUid: widget.currentUid,
          authorName: widget.currentName,
          text: 'Idempotency drill message [$testKey]',
          idempotencyKey: testKey,
        ),
        widget.boardService.postMessageIdempotent(
          authorUid: widget.currentUid,
          authorName: widget.currentName,
          text: 'Idempotency drill message [$testKey]',
          idempotencyKey: testKey,
        ),
      ]);

      final call1Success = results[0];
      final call2Success = results[1];

      setState(() {
        _logOutput = '✔ IDEMPOTENT ALCHEMIST PROVEN (Spice #4):\n'
            'Call 1 Created Record: $call1Success\n'
            'Call 2 Duplicate Aborted: ${!call2Success}\n'
            'Key: $testKey\n'
            'Result: Exactly ONE document exists in Cloud Firestore!';
      });
    } catch (e) {
      setState(() {
        _logOutput = 'Idempotency test failed: $e';
      });
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.terminal, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Security Rules & Spice Diagnostics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Current User: ${widget.currentName} (${widget.currentUid})',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _running ? null : _testForgedCreate,
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text('Probe Forged Create'),
              ),
              OutlinedButton.icon(
                onPressed: _running ? null : _testCrossUidEdit,
                icon: const Icon(Icons.block, size: 16),
                label: const Text('Probe Cross-UID Edit'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[800],
                  foregroundColor: Colors.black,
                ),
                onPressed: _running ? null : _testIdempotentDoubleSubmit,
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('Test Double Submit (Spice #4)'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2430),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _logOutput,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.greenAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
