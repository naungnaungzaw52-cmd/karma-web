// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:karma/main.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final String currentUid;
  final bool isCaller;
  final String? userProfileImageUrl; // 🌟 User ရဲ့ Profile ပုံ URL လက်ခံရန်

  const CallScreen({
    super.key,
    required this.callId,
    required this.currentUid,
    required this.isCaller,
    this.userProfileImageUrl,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isConnecting = true;

  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false; // 🌟 Speaker ဖွင့်/ပိတ် အခြေအနေ

  // 🌟 ဟိုဘက်လူ ကင်မရာပိတ်/ဖွင့်ထားသည်ကို Firestore မှ ဖတ်ရန်
  bool _isRemoteCameraOff = false;

  StreamSubscription? _callStatusSub;
  StreamSubscription? _candidateSub;
  StreamSubscription? _answerSub;
  StreamSubscription? _remoteStateSub;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _listenToRemoteCallState();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _setupWebRTC();
    _listenToCallStatus();
  }

  Future<void> _setupWebRTC() async {
    try {
      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'}
        ]
      });

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });

      if (_localStream != null) {
        _localRenderer.srcObject = _localStream;
        for (var track in _localStream!.getTracks()) {
          _peerConnection!.addTrack(track, _localStream!);
        }
      }

      // Default အနေဖြင့် ဖုန်းခေါ်ဆိုမှု စတင်ချိန်တွင် Speaker ကို On ပေးထားခြင်း
      await Helper.setSpeakerphoneOn(true);
      setState(() {
        _isSpeakerOn = true;
      });

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print(
            "🔥🔥🔥 ဝင်လာပြီဟေ့! Remote Track ရောက်လာပါပြီ: ${event.streams.length} streams");
        if (event.streams.isNotEmpty) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            _isConnecting = false;
            print(
                "✅ Remote Renderer ထဲသို့ Stream အောင်မြင်စွာ ထည့်ပြီးပါပြီ။");
          });
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          String collectionName =
              widget.isCaller ? 'callerCandidates' : 'calleeCandidates';
          FirebaseFirestore.instance
              .collection('calls')
              .doc(widget.callId)
              .collection(collectionName)
              .add(candidate.toMap());
        }
      };

      DocumentReference callRef =
          FirebaseFirestore.instance.collection('calls').doc(widget.callId);
      var callSnapshot = await callRef.get();
      var callData = callSnapshot.data() as Map<String, dynamic>;

      if (widget.isCaller) {
        RTCSessionDescription offer = await _peerConnection!.createOffer();
        await _peerConnection!.setLocalDescription(offer);

        await callRef.update({
          'offer': {'type': offer.type, 'sdp': offer.sdp},
        });

        _answerSub = callRef.snapshots().listen((snapshot) async {
          if (!snapshot.exists) return;
          var data = snapshot.data() as Map<String, dynamic>;

          if (data['answer'] != null && _peerConnection != null) {
            var answer = data['answer'];
            var current = await _peerConnection!.getRemoteDescription();
            if (current == null || current.sdp != answer['sdp']) {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(answer['sdp'], answer['type']),
              );
            }
          }
        });

        _candidateSub = callRef
            .collection('calleeCandidates')
            .snapshots()
            .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              var data = change.doc.data() as Map<String, dynamic>;
              _peerConnection?.addCandidate(
                RTCIceCandidate(
                  data['candidate'],
                  data['sdpMid'],
                  data['sdpMLineIndex'],
                ),
              );
            }
          }
        });
      } else {
        var offer = callData['offer'];
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(offer['sdp'], offer['type']),
        );

        RTCSessionDescription answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

        await callRef.update({
          'answer': {'type': answer.type, 'sdp': answer.sdp},
          'status': 'ongoing',
        });

        _candidateSub = callRef
            .collection('callerCandidates')
            .snapshots()
            .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              var data = change.doc.data() as Map<String, dynamic>;
              print("📥 Caller Candidate အသစ်လက်ခံရရှိပါပြီ");
              _peerConnection?.addCandidate(
                RTCIceCandidate(
                  data['candidate'],
                  data['sdpMid'],
                  data['sdpMLineIndex'],
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      print("WebRTC Setup Error: $e");
    }
  }

  void _toggleMic() {
    if (_localStream != null) {
      bool enabled = _isMicMuted;
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = enabled;
      }
      setState(() {
        _isMicMuted = !_isMicMuted;
      });
    }
  }

  // 🌟 Speaker ဖွင့်/ပိတ် ပြောင်းရန် function
  void _toggleSpeaker() async {
    try {
      setState(() {
        _isSpeakerOn = !_isSpeakerOn;
      });
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      print("🔊 Speakerphone status: $_isSpeakerOn");
    } catch (e) {
      print("Speaker toggle error: $e");
    }
  }

  // 🌟 ကင်မရာပိတ်/ဖွင့်ချိန်တွင် Firestore သို့ အချက်ပြရန်
  void _toggleCamera() async {
    if (_localStream != null) {
      bool enabled = _isCameraOff;
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = enabled;
      }
      setState(() {
        _isCameraOff = !_isCameraOff;
      });

      // Firestore တွင် ကိုယ့်ဘက်က ကင်မရာပိတ်/ဖွင့် အခြေအနေကို ပို့မည်
      String cameraField =
          widget.isCaller ? 'callerCameraOff' : 'calleeCameraOff';
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.callId)
          .update({
        cameraField: _isCameraOff,
      });
    }
  }

  void _switchCamera() async {
    if (_localStream != null) {
      for (var track in _localStream!.getVideoTracks()) {
        await Helper.switchCamera(track);
      }
    }
  }

  // 🌟 ဟိုဘက်လူ ကင်မရာပိတ်ထားခြင်း ရှိမရှိ Firestore မှ စောင့်ဖတ်ခြင်း
  void _listenToRemoteCallState() {
    _remoteStateSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        bool remoteCamOff = widget.isCaller
            ? (data['calleeCameraOff'] ?? false)
            : (data['callerCameraOff'] ?? false);

        setState(() {
          _isRemoteCameraOff = remoteCamOff;
        });
      }
    });
  }

  void _listenToCallStatus() {
    _callStatusSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] == 'ended' || data['status'] == 'rejected') {
          await FlutterCallkitIncoming.endAllCalls();
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _callStatusSub?.cancel();
    _candidateSub?.cancel();
    _answerSub?.cancel();
    _remoteStateSub?.cancel();

    _localStream?.getTracks().forEach((track) => track.stop());
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }

  // 🌟 Profile ပုံ (သို့) Icon ဖြင့် ပြမည့် Avatar Widget
  Widget _buildAvatarView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blueAccent, width: 2),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey,
              backgroundImage: widget.userProfileImageUrl != null &&
                      widget.userProfileImageUrl!.isNotEmpty
                  ? NetworkImage(widget.userProfileImageUrl!)
                  : null,
              child: widget.userProfileImageUrl == null ||
                      widget.userProfileImageUrl!.isEmpty
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            "Camera Off",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1️⃣ ဟိုဘက်လူ့ Video (Remote View) - ကင်မရာပိတ်ထားလျှင် Avatar ပြမည်
          Positioned.fill(
            child: _isRemoteCameraOff
                ? _buildAvatarView()
                : RTCVideoView(_remoteRenderer,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          ),

          if (_isConnecting)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 15),
                  ValueListenableBuilder<bool>(
                    valueListenable: isMyanmarNotifier,
                    builder: (context, isMm, child) {
                      return Text(
                        widget.isCaller
                            ? (isMm ? "ခေါ်ဆိုနေသည်..." : "Calling...")
                            : (isMm ? "ချိတ်ဆက်နေသည်..." : "Connecting..."),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      );
                    },
                  ),
                ],
              ),
            ),

          // 2️⃣ ကိုယ့် Video (Local View) - ကင်မရာပိတ်ထားလျှင် Avatar ပြမည်
          Positioned(
            right: 20,
            top: 50,
            width: 120,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                color: Colors.grey[900],
              ),
              child: _isCameraOff
                  ? _buildAvatarView()
                  : RTCVideoView(_localRenderer, mirror: true),
            ),
          ),

          // 3️⃣ အောက်ခြေထိန်းချုပ်ခလုတ်များ
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // မိုက် ဖွင့်/ပိတ်
                FloatingActionButton(
                  heroTag: 'micBtn',
                  backgroundColor: _isMicMuted ? Colors.red : Colors.grey[800],
                  onPressed: _toggleMic,
                  child: Icon(
                    _isMicMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                // 🌟 Speaker ဖွင့်/ပိတ် ခလုတ်အသစ်
                FloatingActionButton(
                  heroTag: 'speakerBtn',
                  backgroundColor:
                      _isSpeakerOn ? Colors.blue : Colors.grey[800],
                  onPressed: _toggleSpeaker,
                  child: Icon(
                    _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                // ကင်မရာ ရှေ့/နောက် ပြောင်း
                FloatingActionButton(
                  heroTag: 'switchCamBtn',
                  backgroundColor: Colors.grey[800],
                  onPressed: _switchCamera,
                  child: const Icon(Icons.switch_camera, color: Colors.white),
                ),
                const SizedBox(width: 10),
                // ဖုန်းချရန်
                FloatingActionButton(
                  heroTag: 'endCallBtn',
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end, color: Colors.white),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('calls')
                        .doc(widget.callId)
                        .update({'status': 'ended'});

                    await FlutterCallkitIncoming.endAllCalls();

                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 10),
                // ကင်မရာ ဖွင့်/ပိတ်
                FloatingActionButton(
                  heroTag: 'camBtn',
                  backgroundColor: _isCameraOff ? Colors.red : Colors.grey[800],
                  onPressed: _toggleCamera,
                  child: Icon(
                    _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
