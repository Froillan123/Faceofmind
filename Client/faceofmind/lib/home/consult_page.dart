import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class EmotionTallyChart extends StatelessWidget {
  final Map<String, int> tally;
  final Map<String, Color> emotionColors;
  const EmotionTallyChart({super.key, required this.tally, required this.emotionColors});

  @override
  Widget build(BuildContext context) {
    final total = tally.values.fold(0, (a, b) => a + b);
    final entries = tally.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emotion Tally', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800])),
            const SizedBox(height: 8),
            ...entries.map((e) => Row(
              children: [
                Icon(Icons.circle, color: emotionColors[e.key] ?? Colors.grey, size: 16),
                const SizedBox(width: 8),
                Text('${_capitalize(e.key)}', style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: total > 0 ? e.value / total : 0,
                    color: emotionColors[e.key] ?? Colors.grey,
                    backgroundColor: (emotionColors[e.key] ?? Colors.grey).withOpacity(0.15),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            )),
          ],
        ),
      ),
    );
  }
  String _capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

class ConsultPage extends StatefulWidget {
  const ConsultPage({super.key});

  @override
  State<ConsultPage> createState() => _ConsultPageState();
}

class _ConsultPageState extends State<ConsultPage> {
  late stt.SpeechToText _speech;
  FlutterTts? _tts;
  bool _isListening = false;
  bool _permissionsGranted = false;
  bool _isLoading = false;
  String _userInput = '';
  String _aiResponse = '';
  bool _sessionActive = true;
  final Color mainColor = const Color(0xFF5CD581);
  final String geminiApiKey = 'AIzaSyBiPEw3fiJjnL2D5MGAkvhYKpLH36N1N3M';
  final String geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';
  String _pendingRecognizedWords = '';
  String _draftText = '';
  bool _showNoSpeechError = false;
  bool _isMicButtonHeld = false;
  String? _sessionId; // Store session id from backend
  bool _showResult = false;
  Map<String, dynamic>? _resultData;

  // Emotion tally placeholder
  int? _emotionPercent = null; // Start as null, set when detected
  String _emotionLabel = 'Hi how are you today?';

  // New: Tally for detected emotions and conversation
  final List<String> _detectedEmotions = [];
  final List<String> _conversationTurns = [];
  final List<String> _emotionOptions = ['happy', 'sad', 'neutral', 'angry'];

  int _feedbackRating = 0;
  String _feedbackComment = '';
  bool _feedbackSubmitted = false;
  bool _submittingFeedback = false;
  bool _showFeedbackDialog = false;

  bool _showAiLoading = false;
  bool _showSessionProcessing = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _speech.statusListener = _onSpeechStatus;
    _speech.errorListener = _onSpeechError;
    _checkAndRequestMicPermission();
    _createSessionAndStart();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakAI('How are you today?');
    });
    _aiResponse = '';
    _conversationTurns.clear();
  }

  void _onSpeechStatus(String status) async {
    // Removed auto-restart listening
    // if (status == 'notListening' && _sessionActive && !_isLoading) {
    //   await Future.delayed(const Duration(milliseconds: 300));
    //   if (_sessionActive) await _listen();
    // }
  }

  void _onSpeechError(dynamic error) async {
    final errorStr = error.toString();
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      setState(() {
        _isListening = false;
        _sessionActive = false;
        _aiResponse = 'Microphone permission denied. Please enable mic access in settings.';
      });
      return;
    }
    // If permission is granted, show a generic error instead
    setState(() {
      _isListening = false;
      _aiResponse = 'Speech recognition not available. Please try again.';
    });
  }

  Future<void> _retryListening() async {
    setState(() {
      _sessionActive = true;
      _isListening = false;
      // Remove error message
      _aiResponse = 'Hi how are you today?';
    });
    // Do not auto-listen, user must hold button
    // await startListening();
  }

  Future<void> _checkAndRequestMicPermission() async {
    final micStatus = await Permission.microphone.status;
    print('DEBUG: Mic permission status on init: \\${micStatus}');
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      print('DEBUG: Mic permission request result: \\${result}');
      if (!result.isGranted) {
        setState(() {
          _permissionsGranted = false;
          _sessionActive = false;
          _aiResponse = 'Microphone permission denied. Please enable mic access in settings.';
        });
        return;
      }
    }
    setState(() {
      _permissionsGranted = true;
      _aiResponse = '';
      _sessionActive = true;
    });
  }

  Future<void> _startConversation() async {
    setState(() {
      _aiResponse = '';
    });
    // No auto _listen();
  }

  Future<void> _speak(String text) async {
    await _tts?.setLanguage('en-US');
    await _tts?.setVolume(1.0);
    await _tts?.setSpeechRate(0.9);
    await _tts?.setPitch(1.0);
    await _tts?.stop();
    await _tts?.speak(text);
  }

  // NEW: Detect emotion from text
  String detectEmotionFromText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('sad') || lower.contains('cry') || lower.contains('depressed') || lower.contains('condolence') || lower.contains('died') || lower.contains('loss')) {
      return 'sad';
    }
    if (lower.contains('happy') || lower.contains('joy') || lower.contains('excited') || lower.contains('good') || lower.contains('great')) {
      return 'happy';
    }
    if (lower.contains('angry') || lower.contains('mad') || lower.contains('frustrated')) {
      return 'angry';
    }
    if (lower.contains('scared') || lower.contains('afraid') || lower.contains('fear')) {
      return 'fear';
    }
    return 'neutral';
  }

  Future<void> startListening() async {
    // Always check/request permission before listening
    final micStatus = await Permission.microphone.status;
    print('DEBUG: Mic permission status before listening: \\${micStatus}');
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      print('DEBUG: Mic permission request result: \\${result}');
      if (!result.isGranted) {
        setState(() {
          _permissionsGranted = false;
          _sessionActive = false;
          _aiResponse = 'Microphone permission denied. Please enable mic access in settings.';
        });
        return;
      }
    }
    setState(() {
      _permissionsGranted = true;
      _aiResponse = '';
      _sessionActive = true;
    });
    if (!_isListening && _permissionsGranted && !_isLoading && _sessionActive) {
      bool available = await _speech.initialize();
      print('DEBUG: SpeechToText.initialize() result: \\${available}');
      if (available) {
        if (!mounted) return;
        setState(() {
          _isListening = true;
          _pendingRecognizedWords = '';
          _draftText = '';
          _isMicButtonHeld = true;
        });
        _speech.listen(
          onResult: (val) async {
            if (!mounted) return;
            if (val.recognizedWords.trim().isNotEmpty) {
              setState(() {
                _pendingRecognizedWords = val.recognizedWords;
                _draftText = val.recognizedWords;
              });
            } else {
              setState(() {
                _pendingRecognizedWords = '';
                _draftText = '';
              });
            }
          },
          listenFor: const Duration(hours: 1),
          pauseFor: const Duration(hours: 1),
          cancelOnError: false,
          partialResults: true,
          localeId: 'en_US',
        );
      } else {
        setState(() {
          _isListening = false;
          _aiResponse = 'Speech recognition not available. Please check your device.';
        });
      }
    }
  }

  Future<void> stopListening() async {
    if (_isListening && _isMicButtonHeld) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _isMicButtonHeld = false;
      });
      if (_pendingRecognizedWords.trim().isNotEmpty) {
        setState(() {
          _userInput = _pendingRecognizedWords;
          _draftText = '';
          _showNoSpeechError = false;
          _showAiLoading = true;
        });
        setState(() => _isLoading = true);
        // NEW: Use Gemini to detect emotion and generate AI reply
        final geminiResult = await _sendToGeminiSmart(_userInput.trim());
        final detectedEmotion = geminiResult['emotion'] ?? 'neutral';
        final aiReply = geminiResult['ai'] ?? "Let's talk more.";
        setState(() {
          _detectedEmotions.add(detectedEmotion);
          _emotionLabel = detectedEmotion;
          final count = _detectedEmotions.where((e) => e == detectedEmotion).length;
          _emotionPercent = ((_detectedEmotions.isNotEmpty ? count / _detectedEmotions.length : 0) * 100).round();
        });
        _speakAI(aiReply);
        _conversationTurns.add('User - ${_userInput.trim()}');
        _conversationTurns.add('Ai - $aiReply');
        setState(() {
          _isLoading = false;
          _showAiLoading = false;
        });
        _userInput = '';
        _pendingRecognizedWords = '';
      } else {
        setState(() {
          _draftText = '';
          _showNoSpeechError = false;
        });
        // Do nothing on silence
      }
    }
  }

  // NEW: Smarter Gemini call for emotion + reply
  Future<Map<String, String>> _sendToGeminiSmart(String input) async {
    final url = '$geminiApiUrl?key=$geminiApiKey';
    final prompt = '''
You are a mental health support AI. The user may speak in Bisaya or English.

Given the user's message, do the following:
1. Detect the user's emotion (choose one: happy, sad, angry, fear, neutral, surprised, disgust).
2. Write a natural, empathetic, context-aware follow-up question or supportive statement in ENGLISH ONLY (no Bisaya, no code-switching, even if the user speaks Bisaya).

Format your response as:
Emotion: <emotion>
AI: <your reply in English>

User: "$input"
''';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topP": 0.8,
            "topK": 40,
            "maxOutputTokens": 200
          }
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiText = data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString().trim() ?? '';
        // Parse for Emotion: <emotion> and AI: <reply>
        final emotionMatch = RegExp(r'Emotion:\s*(\w+)', caseSensitive: false).firstMatch(aiText);
        final aiMatch = RegExp(r'AI:\s*(.*)', caseSensitive: false, dotAll: true).firstMatch(aiText);
        final emotion = emotionMatch != null ? emotionMatch.group(1)?.toLowerCase() ?? 'neutral' : 'neutral';
        final ai = aiMatch != null ? aiMatch.group(1)?.trim() ?? aiText : aiText;
        return {'emotion': emotion, 'ai': ai};
      }
      return {'emotion': 'neutral', 'ai': "Let's talk more."};
    } catch (e) {
      return {'emotion': 'neutral', 'ai': "Let's talk more."};
    }
  }

  void _stopSession() async {
    setState(() => _sessionActive = false);
    _speech.stop();
    _tts?.stop();
    // Removed: _emotionTimer?.cancel();
    // Removed: _cameraController?.dispose();
    // Removed: emotion tally and transcript logic
    // Just pop the page or show result if needed
    Navigator.of(context).pop();
  }

  Future<void> _createSessionAndStart() async {
    // Call backend to create session
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final res = await ApiService.createSession(token);
    if (res != null && res['success'] == true && res['data'] != null && res['data']['id'] != null) {
      setState(() {
        _sessionId = res['data']['id'].toString();
      });
    }
    // Start camera/emotion detection (no random)
    // _startEmotionDetection(); // REMOVE THIS
  }

  void _endSessionAndProcessEmotion() async {
    print('DEBUG: Starting session processing...');
    setState(() {
      _sessionActive = false;
      _showSessionProcessing = true;
    });
    print('DEBUG: _showSessionProcessing set to true');
    
    _speech.stop();
    _tts?.stop();
    
    // Add a small delay to ensure UI updates
    await Future.delayed(const Duration(milliseconds: 100));
    
    String dominantEmotion = 'neutral';
    if (_detectedEmotions.isNotEmpty) {
      final counts = <String, int>{};
      for (var e in _detectedEmotions) {
          counts[e] = (counts[e] ?? 0) + 1;
      }
      dominantEmotion = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }
    
    final voiceContent = _conversationTurns.join(' ');
    print('DEBUG: Session ID: $_sessionId, Dominant emotion: $dominantEmotion');
    
    if (_sessionId != null) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      print('DEBUG: Calling API to process emotion...');
      final res = await ApiService.processEmotion(token, _sessionId!, dominantEmotion, voiceContent);
      print('DEBUG: API response: $res');
      
      if (!mounted) return;
      
      // Ensure processing modal shows for at least 1 second
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _showSessionProcessing = false;
        if (res != null && res['success'] == true && res['data'] != null) {
            _showResult = true;
          _resultData = res['data'];
        } else {
          _showResult = true;
          _resultData = {
            'suggestions': ['Failed to process emotion. Please try again.'],
            'urls': []
          };
        }
      });
    } else {
      print('DEBUG: No session ID, showing error result');
      
      // Ensure processing modal shows for at least 1 second
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _showSessionProcessing = false;
        _showResult = true;
        _resultData = {
          'suggestions': ['Failed to process emotion. Please try again.'],
          'urls': []
        };
      });
    }
  }

  // Helper to truncate AI prompt to max 5 words
  String _shortPrompt(String prompt) {
    final words = prompt.split(' ');
    if (words.length <= 5) return prompt;
    return words.take(5).join(' ') + '...';
  }

  // Feedback submission
  Future<void> _submitFeedback() async {
    if (_feedbackRating == 0 || _sessionId == null) return;
    setState(() => _submittingFeedback = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    final res = await ApiService.submitFeedback(token, _sessionId!, _feedbackComment, _feedbackRating);
    setState(() {
      _feedbackSubmitted = true;
      _submittingFeedback = false;
    });
  }

  // TTS for AI response
  Future<void> _speakAI(String text) async {
    await _tts?.setLanguage('en-US');
    await _tts?.setVolume(1.0);
    await _tts?.setSpeechRate(0.65); // slower, more natural
    await _tts?.setPitch(0.95); // slightly lower pitch
    await _tts?.stop();
    await _tts?.speak(text);
  }

  @override
  void dispose() {
    _speech.stop();
    _tts?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emotionColors = {
      'happy': Color(0xFF5CD581),
      'sad': Color(0xFF7ED6DF),
      'neutral': Color(0xFFB2BEC3),
      'angry': Color(0xFFFF7675),
    };
    if (!_permissionsGranted) {
      return Scaffold(
        body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              const Text(
                'Microphone permission denied.\nPlease enable in settings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.red),
              ),
                const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => openAppSettings(),
                child: const Text('Go to Settings'),
              ),
            ],
          ),
        ),
      );
    }
    if (_showResult && _resultData != null) {
      // Show result screen
      final voiceContent = _conversationTurns.join(' ');
      final dominantEmotion = _resultData!['emotion'] ?? '';
      final emotionTally = <String, int>{};
      for (var e in _detectedEmotions) {
        emotionTally[e] = (emotionTally[e] ?? 0) + 1;
      }
      final accent = const Color(0xFF5CD581);
      return WillPopScope(
        onWillPop: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please end the session using the End Session button.')),
          );
          return false;
        },
        child: Stack(
          children: [
            Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
                                ElevatedButton.icon(
                                  icon: Icon(Icons.arrow_back, color: Colors.white),
                                  label: Text('Back to Home'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Emotion icon and label
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: Column(
                children: [
                                  Icon(Icons.emoji_emotions, color: accent, size: 54),
                                  const SizedBox(height: 8),
                                  Text(
                                    _capitalize(dominantEmotion),
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accent),
                  ),
                ],
              ),
            ),
                            const SizedBox(height: 18),
                            // Voice content
                            Card(
                              color: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Voice Content', style: TextStyle(fontWeight: FontWeight.bold, color: accent, fontSize: 16)),
                                    const SizedBox(height: 6),
                                    Text(voiceContent, style: TextStyle(color: Colors.grey[800], fontSize: 15)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Suggestions
                            Card(
                              color: accent.withOpacity(0.08),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                                    Row(
                                      children: [
                                        Icon(Icons.lightbulb, color: accent, size: 22),
                            const SizedBox(width: 8),
                                        Text('Wellness Suggestions', style: TextStyle(fontWeight: FontWeight.bold, color: accent, fontSize: 16)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (_resultData!['suggestions'] != null)
                                      ...(_resultData!['suggestions'] as List).map((s) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                          s,
                                          style: TextStyle(fontSize: 15, color: Colors.grey[900]),
                                        ),
                                      )),
                                    // Show URLs if present
                                    if (_resultData!['urls'] != null && (_resultData!['urls'] as List).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Helpful Links:', style: TextStyle(fontWeight: FontWeight.bold, color: accent, fontSize: 15)),
                                            ...(_resultData!['urls'] as List).map((url) => Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              child: InkWell(
                                                onTap: () async {
                                                  if (await canLaunch(url)) {
                                                    await launch(url);
                                                  }
                                                },
                                                child: Text(
                                                  url,
                                                  style: TextStyle(color: Colors.blue[700], decoration: TextDecoration.underline, fontSize: 14),
                                                ),
                                              ),
                                            )),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Feedback button
                            if (!_feedbackSubmitted)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.feedback, color: Colors.white),
                                  label: const Text('Add Feedback'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  onPressed: () => setState(() => _showFeedbackDialog = true),
                                ),
                              ),
                            if (_feedbackSubmitted)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle, color: accent, size: 22),
                                    const SizedBox(width: 6),
                                    Text('Feedback submitted. Thank you!', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_showFeedbackDialog)
                      _buildFeedbackDialog(context, accent),
                  ],
                ),
              ),
            ),
                      if (_showSessionProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  width: 240,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(strokeWidth: 6, color: Colors.white),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Processing...',
                        style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
                      ),
                    );
                  }
    return WillPopScope(
      onWillPop: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please end the session using the End Session button.')),
        );
        return false;
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Column(
                children: [
                  // Top: End Session icon and AI message/loader
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0, left: 16, right: 16, bottom: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 48), // Placeholder for symmetry
                        Expanded(
                          child: Center(
                            child: _showAiLoading
                                ? AnimatedDotsLoader()
                                : (_aiResponse.isNotEmpty
                                    ? Text(
                                        _shortPrompt(_aiResponse),
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black87),
                                        textAlign: TextAlign.center,
                                      )
                                    : const SizedBox.shrink()),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop_circle, color: Colors.red, size: 36),
                          tooltip: 'End Session',
                          onPressed: _endSessionAndProcessEmotion,
                            ),
                          ],
                        ),
                      ),
                  // Middle: Camera preview and emotion label
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Show a static placeholder instead of camera
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(color: mainColor.withOpacity(0.3), width: 4),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Center(
                            child: Icon(Icons.face_retouching_natural, size: 120, color: Colors.black.withOpacity(0.3)),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _emotionLabel.isEmpty ? 'Detecting...' : _emotionLabel,
                          style: const TextStyle(fontSize: 18, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _emotionPercent == null ? '' : '${_emotionPercent}%',
                          style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: mainColor),
                        ),
                      ],
                    ),
              ),
                  // Bottom: Mic button centered
              Padding(
                    padding: const EdgeInsets.only(bottom: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onLongPressStart: (_) => startListening(),
                    onLongPressEnd: (_) => stopListening(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isListening ? mainColor : mainColor.withOpacity(0.7),
                        shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: mainColor.withOpacity(0.2),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(32),
                      child: Icon(
                        Icons.mic,
                        color: Colors.white,
                              size: 48,
                            ),
                          ),
                      ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showSessionProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(strokeWidth: 6, color: Colors.white),
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: 220,
                        child: Text(
                          'Processing...',
                          style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedbackDialog(BuildContext context, Color mainColor) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showFeedbackDialog = false),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: Center(
            child: Material(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _feedbackSubmitted
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: mainColor, size: 40),
                          const SizedBox(height: 8),
                          Text('Thank you for your feedback!', style: TextStyle(color: mainColor, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: Icon(Icons.close, color: Colors.white),
                            label: Text('Close'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            ),
                            onPressed: () => setState(() => _showFeedbackDialog = false),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('How was your session?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: mainColor)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) => IconButton(
                              icon: Icon(Icons.star, color: i < _feedbackRating ? Colors.amber : Colors.grey, size: 32),
                              onPressed: () => setState(() => _feedbackRating = i + 1),
                            )),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Optional comment...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            minLines: 1,
                            maxLines: 3,
                            onChanged: (v) => _feedbackComment = v,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submittingFeedback || _feedbackRating == 0 ? null : _submitFeedback,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              child: _submittingFeedback ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit Feedback'),
                ),
              ),
          ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

class AnimatedDotsLoader extends StatefulWidget {
  const AnimatedDotsLoader({Key? key}) : super(key: key);
  @override
  State<AnimatedDotsLoader> createState() => _AnimatedDotsLoaderState();
}

class _AnimatedDotsLoaderState extends State<AnimatedDotsLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        int dotCount = ((_controller.value * 3).floor() % 4);
        String dots = '.' * dotCount;
        return Text(
          'Thinking$dots',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black54),
        );
      },
    );
  }
} 