import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://192.168.1.2:9000'; // Updated to LAN IP for device/emulator access

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _processResponse(response);
  }

  static Future<Map<String, dynamic>> register(String email, String password, String firstName, String lastName) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      }),
    );
    return _processResponse(response);
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/verify-otp');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    return _processResponse(response);
  }

  static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/request-password-reset');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return _processResponse(response);
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/reset-password');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp, 'new_password': newPassword}),
    );
    return _processResponse(response);
  }

  static Future<List<dynamic>> fetchSessions(String token) async {
    final url = Uri.parse('$baseUrl/api/v1/sessions/');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      return [];
    }
  }

  static Future<int> fetchSessionCount(String token) async {
    final url = Uri.parse('$baseUrl/api/v1/sessions/count');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return data['count'] ?? 0;
    } else {
      return 0;
    }
  }

  static Future<Map<String, dynamic>> fetchProfile(String token) async {
    final url = Uri.parse('$baseUrl/api/v1/users/me');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return _processResponse(response);
  }

  static Future<Map<String, dynamic>> fetchUserById(String token, int userId) async {
    final url = Uri.parse('$baseUrl/api/v1/users/$userId');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return _processResponse(response);
  }

  static Future<List<dynamic>> fetchDominantEmotionChart(String token, {String window = 'week'}) async {
    final url = Uri.parse('$baseUrl/api/v1/sessions/dominant_emotion_chart?window=$window');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }

  static Future<List<dynamic>> fetchIntensityChart(String token, {String window = 'week'}) async {
    final url = Uri.parse('$baseUrl/api/v1/sessions/intensity_chart?window=$window');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }

  // --- Community Posts & Comments ---
  static Future<List<dynamic>> fetchPosts(String token) async {
    final url = Uri.parse('$baseUrl/api/v1/posts/');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print('fetchPosts status: \\${response.statusCode}, body: \\${response.body}');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data;
      } else {
        return [];
      }
    } else {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createPost(String token, String content) async {
    final url = Uri.parse('$baseUrl/api/v1/posts/');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'content': content}),
    );
    return _processResponse(response);
  }

  static Future<List<dynamic>> fetchComments(String token, int postId) async {
    final url = Uri.parse('$baseUrl/api/v1/posts/$postId/comments');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print('fetchComments status: \\${response.statusCode}, body: \\${response.body}');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data;
      } else {
        return [];
      }
    } else {
      return [];
    }
  }

  static Future<Map<String, dynamic>> addComment(String token, int postId, String content) async {
    final url = Uri.parse('$baseUrl/api/v1/posts/$postId/comments');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'content': content}),
    );
    return _processResponse(response);
  }

  static Future<Map<String, dynamic>> editPost(String token, int postId, String content) async {
    final url = Uri.parse('$baseUrl/api/v1/posts/$postId');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'content': content}),
    );
    return _processResponse(response);
  }

  static Future<Map<String, dynamic>> deletePost(String token, int postId) async {
    final url = Uri.parse('$baseUrl/api/v1/posts/$postId');
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return _processResponse(response);
  }

  static Future<Map<String, dynamic>> editComment(String token, int postId, int commentId, String content) async {
    final url = Uri.parse('$baseUrl/api/v1/posts/$postId/comments/$commentId');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'content': content}),
    );
    return _processResponse(response);
  }

  static Future<Map<String, dynamic>> deleteComment(String token, int postId, int commentId) async {
    final url = Uri.parse('$baseUrl/api/v1/posts/$postId/comments/$commentId');
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return _processResponse(response);
  }

  static Map<String, dynamic> _processResponse(http.Response response) {
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true, 'data': data};
    } else {
      return {
        'success': false,
        'message': data['detail'] ?? 'Unknown error',
        'data': data
      };
    }
  }
} 