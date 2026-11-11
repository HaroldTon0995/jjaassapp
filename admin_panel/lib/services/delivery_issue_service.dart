import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;
import '../core/constants/app_constants.dart';
import '../models/delivery_issue_model.dart';

class DeliveryIssueService extends ChangeNotifier {
  static final DeliveryIssueService instance = DeliveryIssueService._();
  DeliveryIssueService._();

  static const String _cacheKey = 'jjaass_delivery_issues_cache';
  final List<DeliveryIssueModel> _issues = [];
  List<DeliveryIssueModel> get issues => List.unmodifiable(_issues);

  RealtimeChannel? _broadcastChannel;
  RealtimeChannel? _postgresChannel;
  StreamSubscription? _streamSub;
  Timer? _pollingTimer;
  bool _initialized = false;
  bool _hasLoadedFromCacheOrServer = false;

  bool get isSupabaseConfigured =>
      AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
      AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY';

  void init() {
    if (_initialized) return;
    _initialized = true;

    _loadFromCache();

    if (isSupabaseConfigured) {
      _initBroadcast();
      _listenToRealtimeStream();
      _fetchDirectIssues();
      _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _fetchDirectIssues(silent: true);
      });
    } else {
      if (_issues.isEmpty) {
        _seedInitialMockIssues();
      }
    }
  }

  void _loadFromCache() {
    if (!kIsWeb) return;
    try {
      final cached = web.window.localStorage.getItem(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final List<dynamic> list = jsonDecode(cached);
        _issues.clear();
        _issues.addAll(
          list.map((m) => DeliveryIssueModel.fromJson(m as Map<String, dynamic>)),
        );
        _hasLoadedFromCacheOrServer = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('DeliveryIssue cache read error: $e');
    }
  }

  void _saveToCache() {
    if (!kIsWeb) return;
    try {
      final list = _issues.map((i) => i.toJson()).toList();
      web.window.localStorage.setItem(_cacheKey, jsonEncode(list));
    } catch (e) {
      debugPrint('DeliveryIssue cache write error: $e');
    }
  }

  void _seedInitialMockIssues() {
    if (_issues.isNotEmpty || _hasLoadedFromCacheOrServer) return;
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
        isTransactionDone: false,
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
                  Map<String, dynamic>.from(payload),
                );
                final idx = _issues.indexWhere((i) => i.id == issue.id);
                if (idx >= 0) {
                  _issues[idx] = issue;
                } else {
                  _issues.insert(0, issue);
                }
                _hasLoadedFromCacheOrServer = true;
                _saveToCache();
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
        _hasLoadedFromCacheOrServer = true;
        bool changed = false;
        for (var f in fetched) {
          final idx = _issues.indexWhere((i) => i.id == f.id);
          if (idx >= 0) {
            if (_issues[idx].status != f.status ||
                _issues[idx].adminFeedback != f.adminFeedback ||
                _issues[idx].isTransactionDone != f.isTransactionDone) {
              _issues[idx] = f;
              changed = true;
            }
          } else {
            _issues.add(f);
            changed = true;
          }
        }
        if (changed || !silent) {
          _saveToCache();
          notifyListeners();
        }
      } else if (!_hasLoadedFromCacheOrServer && _issues.isEmpty) {
        _seedInitialMockIssues();
      }
    } catch (_) {
      // Retain local cached issues silently if offline or table pending
    }
  }

  void _listenToRealtimeStream() {
    if (!isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;

      // 1. Listen for live Postgres changes (realtime WebSockets)
      _postgresChannel = client.channel('public:delivery_issues_realtime');
      _postgresChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'delivery_issues',
            callback: (payload) {
              try {
                final record = payload.newRecord;
                if (record.isNotEmpty) {
                  final issue = DeliveryIssueModel.fromJson(record);
                  final idx = _issues.indexWhere((i) => i.id == issue.id);
                  if (idx >= 0) {
                    _issues[idx] = issue;
                  } else {
                    _issues.insert(0, issue);
                  }
                  _hasLoadedFromCacheOrServer = true;
                  _saveToCache();
                  notifyListeners();
                } else if (payload.eventType == PostgresChangeEvent.delete) {
                  final oldRecord = payload.oldRecord;
                  final id = oldRecord['id']?.toString();
                  if (id != null) {
                    _issues.removeWhere((i) => i.id == id);
                    _saveToCache();
                    notifyListeners();
                  }
                }
              } catch (e) {
                debugPrint('Delivery issues realtime postgres error: $e');
              }
            },
          )
          .subscribe();

      // 2. Continuous stream subscription backup
      _streamSub = client
          .from('delivery_issues')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen((data) {
            final fetched = data
                .map((m) => DeliveryIssueModel.fromJson(m))
                .toList();
            if (fetched.isNotEmpty) {
              _hasLoadedFromCacheOrServer = true;
              for (var f in fetched) {
                final idx = _issues.indexWhere((i) => i.id == f.id);
                if (idx >= 0) {
                  _issues[idx] = f;
                } else {
                  _issues.add(f);
                }
              }
              _saveToCache();
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
      isTransactionDone: false,
    );

    _issues.insert(0, newIssue);
    _hasLoadedFromCacheOrServer = true;
    _saveToCache();
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
        await client.from('delivery_issues').upsert(newIssue.toJson());
      } catch (e) {
        debugPrint('Supabase insert delivery issue error: $e');
      }
    }
  }

  Future<void> acceptIssue(String issueId, {String? adminFeedback, bool markDone = false}) async {
    final idx = _issues.indexWhere((i) => i.id == issueId);
    if (idx < 0) return;

    final updated = _issues[idx].copyWith(
      status: 'accepted',
      adminFeedback: adminFeedback ?? 'Approved for replacement swap on your next order delivery.',
      resolvedAt: DateTime.now(),
      isTransactionDone: markDone,
    );

    _issues[idx] = updated;
    _saveToCache();
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
            .upsert(updated.toJson());
      } catch (e) {
        debugPrint('Supabase accept delivery issue error: $e');
      }
    }
  }

  Future<void> completeTransaction(String issueId) async {
    final idx = _issues.indexWhere((i) => i.id == issueId);
    if (idx < 0) return;

    final updated = _issues[idx].copyWith(
      status: 'completed',
      isTransactionDone: true,
      resolvedAt: DateTime.now(),
    );

    _issues[idx] = updated;
    _saveToCache();
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
            .upsert(updated.toJson());
      } catch (e) {
        debugPrint('Supabase complete delivery issue error: $e');
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
      isTransactionDone: true, // Once declined, the claim transaction is completed/done
    );

    _issues[idx] = updated;
    _saveToCache();
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
            .upsert(updated.toJson());
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
        _issues[i] = _issues[i].copyWith(
          status: 'redeemed',
          isTransactionDone: true,
        );
        remainingToRedeem -= _issues[i].affectedGallonsCount;
        if (isSupabaseConfigured) {
          try {
            Supabase.instance.client
                .from('delivery_issues')
                .upsert(_issues[i].toJson())
                .catchError((_) {});
          } catch (_) {}
        }
        if (remainingToRedeem <= 0) break;
      }
    }
    _saveToCache();
    notifyListeners();
  }

  int getCustomerApprovedSwapGallons(String customerId, String customerName) {
    return _issues
        .where((i) =>
            (i.customerId == customerId || i.customerName == customerName) &&
            i.status == 'accepted' &&
            !i.isTransactionDone)
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
    return _issues.where((i) => i.isPending && !i.isDone).length;
  }

  int get pendingCount => getPendingCount();

  int get activeCount => _issues.where((i) => !i.isDone).length;

  List<DeliveryIssueModel> get activeIssues =>
      _issues.where((i) => !i.isDone).toList();

  List<DeliveryIssueModel> get completedIssues =>
      _issues.where((i) => i.isDone).toList();

  @override
  void dispose() {
    _streamSub?.cancel();
    _broadcastChannel?.unsubscribe();
    _postgresChannel?.unsubscribe();
    _pollingTimer?.cancel();
    super.dispose();
  }
}
