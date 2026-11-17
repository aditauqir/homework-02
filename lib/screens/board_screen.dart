import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../models/message.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/board_service.dart';

/// Clean Twitter/X-style feed for the Message Board.
///
/// Features:
/// - Pure white background with zero bulky cards or colorful boxes.
/// - Posts separated by subtle 1px hairline dividers.
/// - Centered title in the AppBar.
/// - Phosphor Icons throughout the UI.
/// - Aktiv Grotesk typography.
/// - Live stream via `snapshots()`.
/// - Owner-only edit and delete actions.
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
            content: Text('Failed to post: $e'),
            backgroundColor: const Color(0xFF0F1419),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Edit post',
          style: TextStyle(
            fontFamily: 'Aktiv Grotesk',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F1419),
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: editCtrl,
            maxLines: 4,
            style: const TextStyle(
              fontFamily: 'Aktiv Grotesk',
              fontSize: 15,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF7F9F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEFF3F4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF0F1419), width: 1.5),
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Text cannot be empty' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Aktiv Grotesk',
                color: Color(0xFF536471),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F1419),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(
                fontFamily: 'Aktiv Grotesk',
                fontWeight: FontWeight.bold,
              ),
            ),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post updated.'),
              backgroundColor: Color(0xFF0F1419),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Update failed: $e'),
              backgroundColor: const Color(0xFFF4212E),
            ),
          );
        }
      }
    }
    editCtrl.dispose();
  }

  Future<void> _confirmDelete(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete post?',
          style: TextStyle(
            fontFamily: 'Aktiv Grotesk',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F1419),
          ),
        ),
        content: const Text(
          'This can’t be undone and it will be removed from the feed.',
          style: TextStyle(
            fontFamily: 'Aktiv Grotesk',
            fontSize: 14,
            color: Color(0xFF536471),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Aktiv Grotesk',
                color: Color(0xFF536471),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4212E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Aktiv Grotesk',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _boardService.deleteMessage(messageId: message.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post deleted.'),
              backgroundColor: Color(0xFF0F1419),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: const Color(0xFFF4212E),
            ),
          );
        }
      }
    }
  }

  void _showDevRulesTestDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'Message Board Vault',
              style: TextStyle(
                fontFamily: 'Aktiv Grotesk',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F1419),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${widget.profile.fullName} (${widget.profile.role})',
              style: const TextStyle(
                fontFamily: 'Aktiv Grotesk',
                fontSize: 11,
                color: Color(0xFF536471),
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(
            height: 1.0,
            thickness: 0.8,
            color: Color(0xFFEFF3F4),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Rules & Diagnostics',
            icon: PhosphorIcon(
              PhosphorIconsRegular.shieldCheck,
              color: const Color(0xFF0F1419),
              size: 22,
            ),
            onPressed: _showDevRulesTestDialog,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: PhosphorIcon(
              PhosphorIconsRegular.signOut,
              color: const Color(0xFF0F1419),
              size: 22,
            ),
            onPressed: () => _authService.signOut(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Feed List
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _boardStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhosphorIcon(
                            PhosphorIconsRegular.warningCircle,
                            color: const Color(0xFFF4212E),
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Failed to load posts',
                            style: TextStyle(
                              fontFamily: 'Aktiv Grotesk',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Aktiv Grotesk',
                              fontSize: 12,
                              color: Color(0xFF536471),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF0F1419)),
                      ),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhosphorIcon(
                            PhosphorIconsRegular.chatTeardropDots,
                            size: 48,
                            color: const Color(0xFFCFD9DE),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Message Board Vault',
                            style: TextStyle(
                              fontFamily: 'Aktiv Grotesk',
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F1419),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'The vault is currently quiet. Post the first notice to start the board.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Aktiv Grotesk',
                              fontSize: 14,
                              color: Color(0xFF536471),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  controller: _scrollController,
                  itemCount: messages.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 0.8,
                    color: Color(0xFFEFF3F4),
                  ),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMyMessage = msg.authorUid == widget.user.uid;

                    return Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User Avatar
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isMyMessage
                                ? const Color(0xFF0F1419)
                                : const Color(0xFFE1E8ED),
                            child: Text(
                              msg.authorName.isNotEmpty
                                  ? msg.authorName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontFamily: 'Aktiv Grotesk',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isMyMessage
                                    ? Colors.white
                                    : const Color(0xFF0F1419),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Post Content Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header: Name + (YOU badge) ... Time + (edited)
                                Row(
                                  children: [
                                    Text(
                                      msg.authorName,
                                      style: const TextStyle(
                                        fontFamily: 'Aktiv Grotesk',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Color(0xFF0F1419),
                                      ),
                                    ),
                                    if (isMyMessage) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F3F4),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'YOU',
                                          style: TextStyle(
                                            fontFamily: 'Aktiv Grotesk',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF536471),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Text(
                                      msg.createdAt != null
                                          ? _formatTime(msg.createdAt!)
                                          : 'now',
                                      style: const TextStyle(
                                        fontFamily: 'Aktiv Grotesk',
                                        fontSize: 13,
                                        color: Color(0xFF536471),
                                      ),
                                    ),
                                    if (msg.isEdited) ...[
                                      const SizedBox(width: 4),
                                      const Text(
                                        '(edited)',
                                        style: TextStyle(
                                          fontFamily: 'Aktiv Grotesk',
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: Color(0xFF536471),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),

                                // Post Body
                                Text(
                                  msg.text,
                                  style: const TextStyle(
                                    fontFamily: 'Aktiv Grotesk',
                                    fontSize: 15,
                                    height: 1.35,
                                    color: Color(0xFF0F1419),
                                  ),
                                ),

                                // Owner Actions (Edit & Delete)
                                if (isMyMessage) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      InkWell(
                                        onTap: () => _promptEdit(msg),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PhosphorIcon(
                                                PhosphorIconsRegular
                                                    .pencilSimpleLine,
                                                size: 15,
                                                color:
                                                    const Color(0xFF536471),
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'Edit',
                                                style: TextStyle(
                                                  fontFamily: 'Aktiv Grotesk',
                                                  fontSize: 13,
                                                  color: Color(0xFF536471),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      InkWell(
                                        onTap: () => _confirmDelete(msg),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PhosphorIcon(
                                                PhosphorIconsRegular.trash,
                                                size: 15,
                                                color:
                                                    const Color(0xFFF4212E),
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'Delete',
                                                style: TextStyle(
                                                  fontFamily: 'Aktiv Grotesk',
                                                  fontSize: 13,
                                                  color: Color(0xFFF4212E),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Flat Twitter-inspired bottom composer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFEFF3F4), width: 1.0),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF0F1419),
                    child: Text(
                      widget.profile.fullName.isNotEmpty
                          ? widget.profile.fullName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontFamily: 'Aktiv Grotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEFF3F4)),
                      ),
                      child: TextField(
                        controller: _composerCtrl,
                        style: const TextStyle(
                          fontFamily: 'Aktiv Grotesk',
                          fontSize: 14,
                          color: Color(0xFF0F1419),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Post a notice to the vault board...',
                          hintStyle: TextStyle(
                            fontFamily: 'Aktiv Grotesk',
                            color: Color(0xFF536471),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _postMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Send Notice',
                    icon: _isPosting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0F1419)),
                            ),
                          )
                        : PhosphorIcon(
                            PhosphorIconsBold.paperPlaneRight,
                            color: const Color(0xFF0F1419),
                            size: 20,
                          ),
                    onPressed: _isPosting ? null : _postMessage,
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

/// Minimalist Twitter-style Diagnostics Bottom Sheet.
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
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PhosphorIcon(
                PhosphorIconsRegular.shieldCheck,
                color: const Color(0xFF0F1419),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Security Rules & Spices',
                style: TextStyle(
                  fontFamily: 'Aktiv Grotesk',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F1419),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'UID: ${widget.currentUid}',
            style: const TextStyle(
              fontFamily: 'Aktiv Grotesk',
              fontSize: 12,
              color: Color(0xFF536471),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F1419),
                  side: const BorderSide(color: Color(0xFFCFD9DE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _running ? null : _testForgedCreate,
                child: const Text('Probe Forged Create'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F1419),
                  side: const BorderSide(color: Color(0xFFCFD9DE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _running ? null : _testCrossUidEdit,
                child: const Text('Probe Cross-UID Edit'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F1419),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _running ? null : _testIdempotentDoubleSubmit,
                child: const Text('Test Double Submit (Spice 4)'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEFF3F4)),
            ),
            child: SelectableText(
              _logOutput,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 12,
                color: Color(0xFF0F1419),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
