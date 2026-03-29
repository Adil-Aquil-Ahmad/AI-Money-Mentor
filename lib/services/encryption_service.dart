import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static encrypt_pkg.Key? _sessionKey;
  
  static String get _keyAlias {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'chrysos_client_key_$uid';
  }

  /// Ensure we always have a stable 32-Byte master cryptographic key for this user.
  static Future<void> initializeKey() async {
    // If running on Web, fallback to a derived session key strategy (SecureStorage is iffy on browser)
    if (kIsWeb) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      // In a real prod environment, use a PBKDF2 derivative of their password if truly zero-knowledge.
      // For this demo web hybrid, we stretch their UID predictably to 32 chars.
      final padded = uid.padRight(32, '0').substring(0, 32); 
      _sessionKey = encrypt_pkg.Key.fromUtf8(padded);
      return;
    }

    // Native iOS/Android relies purely on Hardware Secure Keystore
    String? base64Key = await _storage.read(key: _keyAlias);
    
    if (base64Key == null) {
      // First boot: Generate a completely random brand new master key 
      final newKey = encrypt_pkg.Key.fromSecureRandom(32);
      await _storage.write(key: _keyAlias, value: newKey.base64);
      _sessionKey = newKey;
    } else {
      // Returning user: Load the existing key
      _sessionKey = encrypt_pkg.Key.fromBase64(base64Key);
    }
  }

  /// Secures outgoing data. Returns a composite payload combining the dynamic IV and the AES-GCM ciphertext.
  static Future<String> wrap(String plainText) async {
    if (_sessionKey == null) await initializeKey();
    if (plainText.isEmpty) return plainText;

    try {
      final iv = encrypt_pkg.IV.fromSecureRandom(16);
      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(_sessionKey!, mode: encrypt_pkg.AESMode.gcm),
      );

      final encrypted = encrypter.encrypt(plainText, iv: iv);
      // Format: IV:CIPHERTEXT
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint('Encryption failed: $e');
      return plainText; // Fallback directly depending on security stance
    }
  }

  /// Destroys the cryptographic shell locally upon data retrieval from backend.
  static Future<String> unwrap(String wrappedText) async {
    if (_sessionKey == null) await initializeKey();
    if (wrappedText.isEmpty || !wrappedText.contains(':')) return wrappedText;

    try {
      final parts = wrappedText.split(':');
      if (parts.length != 2) return wrappedText;

      final iv = encrypt_pkg.IV.fromBase64(parts[0]);
      final encryptedBody = encrypt_pkg.Encrypted.fromBase64(parts[1]);

      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(_sessionKey!, mode: encrypt_pkg.AESMode.gcm),
      );

      return encrypter.decrypt(encryptedBody, iv: iv);
    } catch (e) {
      debugPrint('Decryption failed: $e');
      return wrappedText; // Likely wasn't encrypted to begin with, or parsing error
    }
  }

  /// Helper functions to safely scramble Maps and decode them
  static Future<String> wrapJson(Map<String, dynamic> data) async {
    final stringified = jsonEncode(data);
    return await wrap(stringified);
  }

  static Future<Map<String, dynamic>?> unwrapJson(String wrappedPayload) async {
    if (wrappedPayload.isEmpty) return null;
    final decryptedStr = await unwrap(wrappedPayload);
    try {
      return jsonDecode(decryptedStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
