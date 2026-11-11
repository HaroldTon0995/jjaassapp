import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/delivery_issue_model.dart';

class DeliveryIssueService extends ChangeNotifier {
  static final DeliveryIssueService instance = DeliveryIssueService._();
  DeliveryIssueService._();

  final List<DeliveryIssueModel> _issues = [];
  List<DeliveryIssueModel> get issues => List.unmodifiable(_issues);

  RealtimeChannel? _broadcastChannel;
  StreamSubscription? _streamSub;
  Timer? _pollingTimer;
  bool _initialized = false;

  bool get isSupabaseConfigured => AppConstants.isSupabaseConfigured;

  void init() {
    if (_initialized) return;
    _initialized = true;

    _seedInitialMockIssues();

    if (isSupabaseConfigured) {
      _initBroadcast();
      _listenToRealtimeStream();
      _fetchDirectIssues();
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _fetchDirectIssues(silent: true);
      });
    }
  }

  void _seedInitialMockIssues() {
    if (_issues.isNotEmpty) return;
    final now = DateTime.now();
    _issues.addAll([
      DeliveryIssueModel(
        id: 'CLM-008447',
        orderId: '#ORD-008447',
        customerId: 'usr_haroldcristonborbo',
        customerName: 'haroldcristonborbo',
        customerPhone: '+63 912 345 6789',
        issueType: 'Seal Torn / Damaged',
        affectedGallonsCount: 1,
        description:
            'Cap sanitary plastic shrink seal arrived torn along the neck. Requesting replacement swap container.',
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ]);
  }

  void _initBroadcast() {
    if (!isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      _broadcastChannel = client.channel('jjaass_delivery_issues');
      _broadcastChannel!
          .onBroadcast(
            event: 'issue_updated',
            callback: (payload) {
              try {
                final issue = DeliveryIssueModel.fromJson(
                    Map<String, dynamic>.from(payload));
                final idx = _issues.indexWhere((i) => i.id == issue.id);
                if (idx >= 0) {
                  _issues[idx] = issue;
                } else {
                  _issues.insert(0, issue);
                }
                notifyListeners();
              } catch (e) {
                debugPrint('Issue broadcast parse error: $e');
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Issue broadcast init error: $e');
    }
  }

  Future<void> _fetchDirectIssues({bool silent = false}) async {
    if (!isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      final List<dynamic> res = await client
          .from('delivery_issues')
          .select()
          .order('created_at', ascending: false);
      final fetched = res
          .map((m) => DeliveryIssueModel.fromJson(m as Map<String, dynamic>))
          .toList();

      if (fetched.isNotEmpty) {
        bool changed = false;
        for (var f in fetched) {
          final idx = _issues.indexWhere((i) => i.id == f.id);
          if (idx >= 0) {
            if (_issues[idx].status != f.status ||
                _issues[idx].adminFeedback != f.adminFeedback) {
              _issues[idx] = f;
              changed = true;
            }
          } else {
            _issues.add(f);
            changed = true;
          }
        }
        if (changed || !silent) {
          notifyListeners();
        }
      }
    } catch (_) {
      // Table may not exist yet in Supabase; retain local memory issues silently
    }
  }

  void _listenToRealtimeStream() {
    if (!isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      _streamSub = client
          .from('delivery_issues')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen((data) {
            final fetched = data
                .map((m) => DeliveryIssueModel.fromJson(m))
                .toList();
            if (fetched.isNotEmpty) {
              _issues.clear();
              _issues.addAll(fetched);
              notifyListeners();
            }
          }, onError: (err) {
            debugPrint('Delivery issues stream error: $err');
          });
    } catch (e) {
      debugPrint('Delivery issues stream init error: $e');
    }
  }

  Future<void> submitIssue({
    required String orderId,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String issueType,
    required int affectedGallonsCount,
    String? photoUrl,
    String? photoBase64,
    required String description,
  }) async {
    final cleanId = 'CLM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final newIssue = DeliveryIssueModel(
      id: cleanId,
      orderId: orderId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      issueType: issueType,
      affectedGallonsCount: affectedGallonsCount,
      photoUrl: photoUrl,
      photoBase64: photoBase64,
      description: description.trim(),
      status: 'pending',
      createdAt: DateTime.now(),
    );

    _issues.insert(0, newIssue);
    notifyListeners();

    if (isSupabaseConfigured) {
      try {
        _broadcastChannel?.sendBroadcastMessage(
          event: 'issue_updated',
          payload: newIssue.toJson(),
        );
      } catch (_) {}

      try {
        final client = Supabase.instance.client;
        await client.from('delivery_issues').insert(newIssue.toJson());
      } catch (e) {
        debugPrint('Supabase insert delivery issue error: $e');
      }
    }
  }

  Future<void> acceptIssue(String issueId, {String? adminFeedback}) async {
    final idx = _issues.indexWhere((i) => i.id == issueId);
    if (idx < 0) return;

    final updated = _issues[idx].copyWith(
      status: 'accepted',
      adminFeedback: adminFeedback ?? 'Approved for replacement swap on your next order delivery.',
      resolvedAt: DateTime.now(),
    );

    _issues[idx] = updated;
    notifyListeners();

    if (isSupabaseConfigured) {
      try {
        _broadcastChannel?.sendBroadcastMessage(
          event: 'issue_updated',
          payload: updated.toJson(),
        );
      } catch (_) {}

      try {
        final client = Supabase.instance.client;
        await client
            .from('delivery_issues')
            .update(updated.toJson())
            .eq('id', issueId);
      } catch (e) {
        debugPrint('Supabase accept delivery issue error: $e');
      }
    }
  }

  Future<void> declineIssue(String issueId, String reason) async {
    final idx = _issues.indexWhere((i) => i.id == issueId);
    if (idx < 0) return;

    final updated = _issues[idx].copyWith(
      status: 'declined',
      adminFeedback: reason.trim(),
      resolvedAt: DateTime.now(),
    );

    _issues[idx] = updated;
    notifyListeners();

    if (isSupabaseConfigured) {
      try {
        _broadcastChannel?.sendBroadcastMessage(
          event: 'issue_updated',
          payload: updated.toJson(),
        );
      } catch (_) {}

      try {
        final client = Supabase.instance.client;
        await client
            .from('delivery_issues')
            .update(updated.toJson())
            .eq('id', issueId);
      } catch (e) {
        debugPrint('Supabase decline delivery issue error: $e');
      }
    }
  }

  void redeemSwap(String customerId, int gallonsCount) {
    int remainingToRedeem = gallonsCount;
    for (int i = 0; i < _issues.length; i++) {
      if ((_issues[i].customerId == customerId || _issues[i].customerName == customerId) &&
          _issues[i].status == 'accepted') {
        _issues[i] = _issues[i].copyWith(status: 'redeemed');
        remainingToRedeem -= _issues[i].affectedGallonsCount;
        if (isSupabaseConfigured) {
          try {
            Supabase.instance.client
                .from('delivery_issues')
                .update({'status': 'redeemed'})
                .eq('id', _issues[i].id)
                .catchError((_) {});
          } catch (_) {}
        }
        if (remainingToRedeem <= 0) break;
      }
    }
    notifyListeners();
  }

  int getCustomerApprovedSwapGallons(String customerId, String customerName) {
    return _issues
        .where((i) =>
            (i.customerId == customerId || i.customerName == customerName) &&
            i.status == 'accepted')
        .fold(0, (sum, i) => sum + i.affectedGallonsCount);
  }

  List<DeliveryIssueModel> getCustomerIssues(String customerId, String customerName) {
    return _issues
        .where((i) => i.customerId == customerId || i.customerName == customerName)
        .toList();
  }

  DeliveryIssueModel? getIssueByOrderId(String orderId) {
    try {
      return _issues.firstWhere(
        (i) => i.orderId == orderId || i.orderId == '#$orderId' || '#${i.orderId}' == orderId,
      );
    } catch (_) {
      return null;
    }
  }

  int getPendingCount() {
    return _issues.where((i) => i.status == 'pending').length;
  }

  int get pendingCount => getPendingCount();

  @override
  void dispose() {
    _streamSub?.cancel();
    _broadcastChannel?.unsubscribe();
    _pollingTimer?.cancel();
    super.dispose();
  }
}
