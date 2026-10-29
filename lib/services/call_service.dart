// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'notification_service.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ၁။ ဖုန်းခေါ်ဆိုမှု စတင်ခြင်း (Caller ဘက်မှ လုပ်ဆောင်ချက်)
  Future<String> startCall({
    required String callerId,
    required String callerName,
    required String receiverId,
    String? callerAvatar,
  }) async {
    try {
      RTCPeerConnection peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'}
        ]
      });

      RTCSessionDescription offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);

      DocumentReference callRef = _firestore.collection('calls').doc();

      await callRef.set({
        'callId': callRef.id,
        'callerId': callerId,
        'callerName': callerName,
        'receiverId': receiverId,
        'callerAvatar': callerAvatar,
        'status': 'calling', // 👈 စစချင်း status က 'calling' ဖြစ်နေပါမည်
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
        'answer': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      try {
        DocumentSnapshot receiverDoc =
            await _firestore.collection('users').doc(receiverId).get();

        if (receiverDoc.exists) {
          var receiverData = receiverDoc.data() as Map<String, dynamic>?;
          if (receiverData != null && receiverData.containsKey('fcmToken')) {
            String? receiverToken = receiverData['fcmToken'];
            if (receiverToken != null && receiverToken.isNotEmpty) {
              await NotificationService.sendNotification(
                receiverToken,
                "   ",
                "  ",
                'call',
                callId: callRef.id,
                callerName: callerName,
                callerAvatar: callerAvatar,
              );
              print("🔥 Call Notification successfully sent to receiver!");
            }
          }
        }
      } catch (notifError) {
        print("Error sending call notification: $notifError");
      }

      print("Call successfully initiated with ID: ${callRef.id}");
      return callRef.id;
    } catch (e) {
      print("Error starting call: $e");
      return '';
    }
  }

  // ၂။ ဖုန်းချလိုက်ခြင်း / ငြင်းပယ်ခြင်း (End / Reject Call)
  Future<void> endCall(callId, {String? receiverId, String? currentUid}) async {
    try {
      DocumentSnapshot callDoc =
          await _firestore.collection('calls').doc(callId).get();

      String actualReceiverId = receiverId ?? '';

      if (callDoc.exists) {
        var callData = callDoc.data() as Map<String, dynamic>;
        actualReceiverId = callData['receiverId'] ?? actualReceiverId;
      }

      // ဖုန်းခေါ်ဆိုမှု အခြေအနေကို 'ended' သို့ ပြောင်းခြင်း
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
      });

      // ဖုန်းကျသွားကြောင်း အခြားဘက်သို့ FCM notification ပို့ရန်
      if (actualReceiverId.isNotEmpty) {
        DocumentSnapshot receiverDoc =
            await _firestore.collection('users').doc(actualReceiverId).get();

        if (receiverDoc.exists) {
          var receiverData = receiverDoc.data() as Map<String, dynamic>?;
          if (receiverData != null && receiverData.containsKey('fcmToken')) {
            String? receiverToken = receiverData['fcmToken'];
            if (receiverToken != null && receiverToken.isNotEmpty) {
              await NotificationService.sendNotification(
                receiverToken,
                "end_call",
                "Call ended",
                'end_call',
                callId: callId,
              );
            }
          }
        }
      }
    } catch (e) {
      print("Error ending call: $e");
    }
  }
}
