// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/foundation.dart';
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
// ICE Candidate Management
  bool _remoteDescriptionSet = false;

  final List<RTCIceCandidate> _pendingCandidates = [];

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
    try {
      print("STEP 1: Local Renderer Initializing");

      await _localRenderer.initialize();

      print("STEP 2: Local Renderer Initialized");

      await _remoteRenderer.initialize();

      print("STEP 3: Remote Renderer Initialized");

      await _setupWebRTC();

      print("STEP 4: WebRTC Setup Completed");

      _listenToCallStatus();
    } catch (e, stackTrace) {
      print("❌ RENDERER INIT ERROR: $e");
      print(stackTrace);
    }
  }
// =====================================================
  // ICE CANDIDATE MANAGEMENT
  // =====================================================

  Future<void> _addRemoteCandidate(Map<String, dynamic> data) async {
    try {
      if (_peerConnection == null) {
        print("❌ PeerConnection is NULL");
        return;
      }

      final candidate = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );

      if (!_remoteDescriptionSet) {
        _pendingCandidates.add(candidate);

        print(
          "⏳ ICE Candidate queued. "
          "Total: ${_pendingCandidates.length}",
        );

        return;
      }

      await _peerConnection!.addCandidate(candidate);

      print("✅ Remote ICE Candidate Added Successfully");
    } catch (e) {
      print("❌ Add Remote Candidate Error: $e");
    }
  }

  Future<void> _flushPendingCandidates() async {
    if (_peerConnection == null) return;

    print(
      "📦 Processing Pending Candidates: "
      "${_pendingCandidates.length}",
    );

    for (final candidate in _pendingCandidates) {
      try {
        await _peerConnection!.addCandidate(candidate);

        print("✅ Pending ICE Candidate Added");
      } catch (e) {
        print("❌ Pending Candidate Error: $e");
      }
    }

    _pendingCandidates.clear();

    print("📦 Pending Candidate Queue Cleared");
  }

  Future<void> _setupWebRTC() async {
    try {
      print("WEBRTC STEP 1: Before createPeerConnection");

      _peerConnection = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ]
      });

      print("WEBRTC STEP 2: After createPeerConnection");

      // ICE Connection Monitoring
      _peerConnection!.onIceConnectionState = (state) {
        print("🧊 ICE CONNECTION STATE: $state");
      };

      _peerConnection!.onConnectionState = (state) {
        print("🔗 PEER CONNECTION STATE: $state");
      };

      _peerConnection!.onIceGatheringState = (state) {
        print("📡 ICE GATHERING STATE: $state");

        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          print("✅ ICE GATHERING COMPLETED");
        }
      };
      // Remote Track Monitoring
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print("🎥 REMOTE TRACK RECEIVED");
        print("🎥 Track Kind: ${event.track.kind}");
        print("🎥 Track Enabled: ${event.track.enabled}");
        print("🎥 Track Muted: ${event.track.muted}");

        print(
          "🔥 Remote Track ရောက်လာပါပြီ: "
          "${event.streams.length} streams",
        );

        if (event.streams.isNotEmpty && mounted) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            _isConnecting = false;
          });
        }
      };

      // Get User Media
      print("WEBRTC STEP 3: Getting User Media");

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': 640,
          'height': 480,
        },
      });

      print("WEBRTC STEP 4: User Media Obtained");

      print("STEP 5: Before setting local renderer");

      if (kIsWeb) {
        final cameras = await Helper.cameras;

        print("📸 Available Cameras: ${cameras.length}");

        for (int i = 0; i < cameras.length; i++) {
          print("CAMERA [$i]");
          print("Label: ${cameras[i].label}");
          print("Device ID: ${cameras[i].deviceId}");
        }
      }

      if (_localStream != null) {
        _localRenderer.srcObject = _localStream;

        print("STEP 6: Local renderer assigned");

        // 🎵 AUDIO / VIDEO TRACK ORDER MONITORING
        for (var track in _localStream!.getTracks()) {
          print("🎵 LOCAL TRACK KIND: ${track.kind}");

          await _peerConnection!.addTrack(
            track,
            _localStream!,
          );

          print("✅ TRACK ADDED: ${track.kind}");
        }
      }
      print("STEP 9: Before setSpeakerphoneOn");

      if (!kIsWeb) {
        await Helper.setSpeakerphoneOn(true);
      }

      print("STEP 10: After setSpeakerphoneOn");

      if (mounted) {
        setState(() {
          _isSpeakerOn = true;
        });
      }
      // 2. Remote Track လက်ခံခြင်း
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print(
            "🔥🔥🔥 Remote Track ရောက်လာပါပြီ: ${event.streams.length} streams");
        if (event.streams.isNotEmpty) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            _isConnecting = false;
          });
        }
      };
      void logMediaLines(String label, String? sdp) {
        print('========== $label ==========');

        for (final line in (sdp ?? '').split('\n')) {
          if (line.startsWith('m=')) {
            print(line);
          }
        }

        print('============================');
      }

      // =====================================================
// ICE CANDIDATE UPLOAD + TYPE MONITORING
// =====================================================

      _peerConnection!.onIceCandidate = (
        RTCIceCandidate candidate,
      ) async {
        if (candidate.candidate == null) return;

        try {
          final candidateText = candidate.candidate!;

          String candidateType = 'unknown';

          if (candidateText.contains(' typ host')) {
            candidateType = 'host';
          } else if (candidateText.contains(' typ srflx')) {
            candidateType = 'srflx';
          } else if (candidateText.contains(' typ relay')) {
            candidateType = 'relay';
          } else if (candidateText.contains(' typ prflx')) {
            candidateType = 'prflx';
          }

          // Candidate Diagnostic
          print("🧊 ICE TYPE: $candidateType");
          print("🧊 ICE MID: ${candidate.sdpMid}");
          print("🧊 ICE MLINE: ${candidate.sdpMLineIndex}");

          String collectionName =
              widget.isCaller ? 'callerCandidates' : 'calleeCandidates';

          // မူလ Firestore Upload Logic
          await FirebaseFirestore.instance
              .collection('calls')
              .doc(widget.callId)
              .collection(collectionName)
              .add(candidate.toMap());

          print("📤 ICE Candidate Uploaded: $collectionName");
        } catch (e) {
          print("❌ ICE Candidate Upload Error: $e");
        }
      };

      DocumentReference callRef =
          FirebaseFirestore.instance.collection('calls').doc(widget.callId);

      // =====================================================
      // CALLER LOGIC
      // =====================================================

      if (widget.isCaller) {
        print("📞 CALLER: Creating Offer");

        RTCSessionDescription offer = await _peerConnection!.createOffer();

// 🔍 SDP Media Lines စစ်မယ်
        logMediaLines('CALLER OFFER', offer.sdp);

        await _peerConnection!.setLocalDescription(offer);

        await callRef.update({
          'offer': {
            'type': offer.type,
            'sdp': offer.sdp,
          },
        });

        print("✅ Caller Offer Uploaded");

        // Listen for Answer
        _answerSub = callRef.snapshots().listen(
          (snapshot) async {
            try {
              if (!snapshot.exists) return;

              var data = snapshot.data() as Map<String, dynamic>;

              if (data['answer'] != null &&
                  _peerConnection != null &&
                  !_remoteDescriptionSet) {
                var answer = data['answer'];

                print("📥 Caller Received Answer");

                await _peerConnection!.setRemoteDescription(
                  RTCSessionDescription(
                    answer['sdp'],
                    answer['type'],
                  ),
                );

                _remoteDescriptionSet = true;

                print("✅ Caller Remote Description Set");

                await _flushPendingCandidates();
              }
            } catch (e) {
              print("❌ Answer Listener Error: $e");
            }
          },
        );

        // Listen for Callee Candidates
        _candidateSub =
            callRef.collection('calleeCandidates').snapshots().listen(
          (snapshot) async {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                print("📥 Caller Received Callee Candidate");

                await _addRemoteCandidate(
                  change.doc.data() as Map<String, dynamic>,
                );
              }
            }
          },
          onError: (e) {
            print("❌ Callee Candidate Listener Error: $e");
          },
        );
      } else {
        // =====================================================
        // CALLEE LOGIC
        // =====================================================

        print("📲 CALLEE: Getting Caller Offer");

        // 1. Get Call Document
        var callSnapshot = await callRef.get();

        if (!callSnapshot.exists) {
          print("❌ Call Document Not Found");
          return;
        }

        var callData = callSnapshot.data() as Map<String, dynamic>;

        var offer = callData['offer'];

        if (offer == null) {
          print("❌ Caller Offer Not Found");
          return;
        }

        // 2. Set Remote Description
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(
            offer['sdp'],
            offer['type'],
          ),
        );

        _remoteDescriptionSet = true;

        print("✅ Callee Remote Description Set");

        // 3. Add Pending ICE Candidates
        await _flushPendingCandidates();

        // 4. Listen for Caller ICE Candidates
        _candidateSub =
            callRef.collection('callerCandidates').snapshots().listen(
          (snapshot) async {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                print("📥 Callee Received Caller Candidate");

                var data = change.doc.data() as Map<String, dynamic>;

                await _addRemoteCandidate(data);
              }
            }
          },
          onError: (e) {
            print("❌ Caller Candidate Listener Error: $e");
          },
        );

        // 5. Create Answer
        print("📞 CALLEE: Creating Answer");

        RTCSessionDescription answer = await _peerConnection!.createAnswer();

// 🔍 SDP Media Lines စစ်မယ်
        logMediaLines('CALLEE ANSWER', answer.sdp);

        await _peerConnection!.setLocalDescription(answer);

        print("✅ Callee Local Description Set");

        // 7. Upload Answer to Firestore
        await callRef.update({
          'answer': {
            'type': answer.type,
            'sdp': answer.sdp,
          },
          'status': 'ongoing',
        });

        print(
          "✅ Callee generated and uploaded answer successfully.",
        );
      }
    } catch (e, stackTrace) {
      print("❌ WebRTC Setup Error: $e");
      print(stackTrace);
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
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });

    try {
      if (kIsWeb) {
        // Web မှာ Remote Audio ကို Mute / Unmute လုပ်မယ်
        _remoteRenderer.muted = !_isSpeakerOn;
      } else {
        // Android / iOS မှာ Speaker Route ပြောင်းမယ်
        await Helper.setSpeakerphoneOn(_isSpeakerOn);
      }

      print("🔊 Speaker status: $_isSpeakerOn");
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

  Future<void> _switchCamera() async {
    if (_localStream == null || _peerConnection == null) return;

    try {
      final cameras = await Helper.cameras;

      if (cameras.length <= 1) {
        print("⚠️ Only one camera available.");
        return;
      }

      final videoTracks = _localStream!.getVideoTracks();

      if (videoTracks.isEmpty) return;

      final oldTrack = videoTracks.first;

      // လက်ရှိ Video Sender ကို ရှာမယ်
      RTCRtpSender? videoSender;

      for (final sender in await _peerConnection!.getSenders()) {
        if (sender.track?.kind == 'video') {
          videoSender = sender;
          break;
        }
      }

      if (videoSender == null) {
        print("❌ Video Sender not found!");
        return;
      }

      // လက်ရှိ Camera ID
      final currentDeviceId = oldTrack.getSettings()['deviceId'];

      // နောက် Camera ကို ရွေးမယ်
      final nextCamera = cameras.firstWhere(
        (camera) => camera.deviceId != currentDeviceId,
      );

      print("🔄 Switching to: ${nextCamera.label}");

      // Camera အသစ်ပြောင်းမယ်
      await Helper.switchCamera(
        oldTrack,
        nextCamera.deviceId,
        _localStream!,
      );

      // Stream ထဲက Camera Track အသစ်ယူမယ်
      final newTrack = _localStream!.getVideoTracks().first;

      // Peer Connection Sender ကို Track အသစ်ပြောင်းပေးမယ်
      await videoSender.replaceTrack(newTrack);

      _localRenderer.srcObject = _localStream;

      if (mounted) {
        setState(() {});
      }

      print("✅ Camera switched and Video Sender replaced!");
    } catch (e) {
      print("❌ Camera Switch Error: $e");
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
          if (!kIsWeb) {
            await FlutterCallkitIncoming.endAllCalls();
          }

          // 🌟 Navigator သေချာထွက်နိုင်ရန် Safe check ထပ်ထည့်ခြင်း
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
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

                    if (!kIsWeb) {
                      // 🌟 Web မဟုတ်မှသာ CallKit ကို ပိတ်ရန်
                      await FlutterCallkitIncoming.endAllCalls();
                    }

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
