import 'package:firebase_database/firebase_database.dart';

import '../models/models.dart';
import 'support_ai_service.dart';

class SupportActionEngine {
  const SupportActionEngine();

  Future<bool> cancelOrder({
    required DatabaseReference Function(String path) ref,
    required String nowIso,
    required OrderModel order,
    required AppUser actor,
  }) async {
    final status = order.status.toLowerCase();
    if (order.userId != actor.id) {
      return false;
    }
    if (!(status == 'placed' ||
        status == 'pending_payment' ||
        status == 'confirmed')) {
      return false;
    }
    await ref('orders/${order.id}').update({
      'status': 'Cancelled',
      'deliveryStatus': 'Cancelled',
      'updatedAt': nowIso,
    });
    return true;
  }

  Future<bool> requestRefund({
    required DatabaseReference Function(String path) ref,
    required String nowIso,
    required OrderModel order,
    required AppUser actor,
    required SupportChat chat,
    String? reason,
  }) async {
    if (order.userId != actor.id) {
      return false;
    }
    final status = order.status.toLowerCase();
    final eligible =
        status == 'delivered' || status == 'cancelled' || order.isPaymentVerified;
    if (!eligible) {
      return false;
    }
    await ref('').update({
      'supportChats/${chat.id}/status': 'waiting',
      'supportChats/${chat.id}/updatedAt': nowIso,
      'supportTickets/${chat.ticketId}/status': 'waiting',
      'supportTickets/${chat.ticketId}/resolvedAt': null,
      'supportTickets/${chat.ticketId}/requestedAction': 'refund',
      'supportTickets/${chat.ticketId}/refundOrderId': order.id,
      'supportTickets/${chat.ticketId}/refundReason': reason?.trim() ?? '',
      'supportTickets/${chat.ticketId}/refundRequestedAt': nowIso,
    });
    return true;
  }

  Future<bool> requestReturn({
    required DatabaseReference Function(String path) ref,
    required String nowIso,
    required OrderModel order,
    required AppUser actor,
    required SupportChat chat,
    String? reason,
  }) async {
    if (order.userId != actor.id) {
      return false;
    }
    final delivered = order.isDelivered || order.status.toLowerCase() == 'delivered';
    final customOrder = order.orderType == 'custom_tailoring' || order.items.any((item) => item.isCustomTailoring);
    if (!delivered || customOrder) {
      return false;
    }
    await ref('').update({
      'supportChats/${chat.id}/status': 'waiting',
      'supportChats/${chat.id}/updatedAt': nowIso,
      'supportTickets/${chat.ticketId}/status': 'waiting',
      'supportTickets/${chat.ticketId}/resolvedAt': null,
      'supportTickets/${chat.ticketId}/requestedAction': 'return',
      'supportTickets/${chat.ticketId}/returnOrderId': order.id,
      'supportTickets/${chat.ticketId}/returnReason': reason?.trim() ?? '',
      'supportTickets/${chat.ticketId}/returnRequestedAt': nowIso,
    });
    return true;
  }

  Future<bool> updateSavedAddress({
    required DatabaseReference Function(String path) ref,
    required String nowIso,
    required AppUser actor,
    required String address,
  }) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final segments = trimmed
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final city = segments.length >= 2 ? segments[segments.length - 2] : actor.city;
    await ref('users/${actor.id}').update({
      'address': trimmed,
      if ((city ?? '').trim().isNotEmpty) 'city': city,
      'locationUpdatedAt': nowIso,
    });
    return true;
  }

  String nextSupportStatus({
    required SupportActionType action,
    required SupportChat chat,
    required bool isAdminActor,
  }) {
    if (isAdminActor) {
      return chat.status == 'closed' ? 'closed' : 'open';
    }
    if (action == SupportActionType.requestRefund) {
      return 'waiting';
    }
    if (action == SupportActionType.requestReturn) {
      return 'waiting';
    }
    return 'open';
  }
}
