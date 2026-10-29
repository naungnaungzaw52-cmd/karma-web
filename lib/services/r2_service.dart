// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb အတွက်
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // MediaType အတွက်

class R2Service {
  // Cloudflare Worker ရဲ့ URL
  static const String _workerUrl =
      "https://karma-api777.naungnaungzaw52.workers.dev";

  // ဖိုင်တင်ရန် Method
  static Future<String?> uploadFile(dynamic fileObj, String folderName) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_workerUrl/upload'),
      );

      request.fields['folder'] = folderName;

      if (kIsWeb) {
        // 🌟 Flutter Web အတွက် bytes ကို ယူခြင်း
        Uint8List fileBytes = await fileObj.readAsBytes();
        String fileName = fileObj.name;

        // 🌟 Worker ရဲ့ file.stream() နဲ့ 100% ကိုက်ညီစေရန် StreamedFile ပုံစံဖြင့် ထည့်သွင်းခြင်း
        var multipartFile = http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        );

        request.files.add(multipartFile);
      } else {
        // 🌟 Mobile (Android / iOS) အတွက်
        File file = fileObj is File ? fileObj : File(fileObj.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        print("R2 Upload Success: ${data['fileUrl']}");
        return data['fileUrl'];
      } else {
        print("R2 Upload Failed: ${response.body}");
        return null;
      }
    } catch (e) {
      print("R2 Upload Exception: $e");
      return null;
    }
  }

  // ဖိုင်ဖျက်ရန် Method
  static Future<void> deleteFile(String fileUrl) async {
    try {
      var response = await http.post(
        Uri.parse('$_workerUrl/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fileUrl': fileUrl}),
      );

      if (response.statusCode == 200) {
        print("R2 Delete Success: $fileUrl");
      } else {
        print("R2 Delete Failed: ${response.body}");
      }
    } catch (e) {
      print("R2 Delete Exception: $e");
    }
  }
}
