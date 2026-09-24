import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

// FFI Definitions for Crypt32 and Kernel32
final DynamicLibrary _crypt32 = DynamicLibrary.open('crypt32.dll');
final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}

typedef _CryptProtectDataNative =
    Int32 Function(
      Pointer<_DataBlob> pDataIn,
      Pointer<Void> szDataDescr,
      Pointer<_DataBlob> pOptionalEntropy,
      Pointer<Void> pvReserved,
      Pointer<Void> pPromptStruct,
      Uint32 dwFlags,
      Pointer<_DataBlob> pDataOut,
    );
typedef _CryptProtectDataDart =
    int Function(
      Pointer<_DataBlob> pDataIn,
      Pointer<Void> szDataDescr,
      Pointer<_DataBlob> pOptionalEntropy,
      Pointer<Void> pvReserved,
      Pointer<Void> pPromptStruct,
      int dwFlags,
      Pointer<_DataBlob> pDataOut,
    );

typedef _CryptUnprotectDataNative =
    Int32 Function(
      Pointer<_DataBlob> pDataIn,
      Pointer<Pointer<Void>> ppszDataDescr,
      Pointer<_DataBlob> pOptionalEntropy,
      Pointer<Void> pvReserved,
      Pointer<Void> pPromptStruct,
      Uint32 dwFlags,
      Pointer<_DataBlob> pDataOut,
    );
typedef _CryptUnprotectDataDart =
    int Function(
      Pointer<_DataBlob> pDataIn,
      Pointer<Pointer<Void>> ppszDataDescr,
      Pointer<_DataBlob> pOptionalEntropy,
      Pointer<Void> pvReserved,
      Pointer<Void> pPromptStruct,
      int dwFlags,
      Pointer<_DataBlob> pDataOut,
    );

typedef _LocalAllocNative =
    Pointer<Void> Function(Uint32 uFlags, IntPtr uBytes);
typedef _LocalAllocDart = Pointer<Void> Function(int uFlags, int uBytes);

typedef _LocalFreeNative = Pointer<Void> Function(Pointer<Void> hMem);
typedef _LocalFreeDart = Pointer<Void> Function(Pointer<Void> hMem);

const int _lmemZeroInit = 0x0040;
const int _cryptprotectUiForbidden = 0x1;

final _CryptProtectDataDart _cryptProtectData = _crypt32
    .lookupFunction<_CryptProtectDataNative, _CryptProtectDataDart>(
      'CryptProtectData',
    );

final _CryptUnprotectDataDart _cryptUnprotectData = _crypt32
    .lookupFunction<_CryptUnprotectDataNative, _CryptUnprotectDataDart>(
      'CryptUnprotectData',
    );

final _LocalAllocDart _localAlloc = _kernel32
    .lookupFunction<_LocalAllocNative, _LocalAllocDart>('LocalAlloc');

final _LocalFreeDart _localFree = _kernel32
    .lookupFunction<_LocalFreeNative, _LocalFreeDart>('LocalFree');

/// Helper for Windows Data Protection API (DPAPI) encryption/decryption.
///
/// Encrypts secrets tied to the current logged-in Windows user account.
/// Requires 0 external pub packages. Falls back safely if not on Windows.
class DpapiHelper {
  static const String prefix = 'dpapi:';

  /// Returns true if DPAPI is supported on current OS.
  static bool get isSupported => Platform.isWindows;

  /// Encrypts plaintext using DPAPI and returns `dpapi:<base64>`.
  /// If [plainText] is empty or OS is not Windows, returns [plainText] as is.
  static String encrypt(String plainText) {
    if (!isSupported || plainText.isEmpty) return plainText;

    try {
      final utf8Bytes = utf8.encode(plainText);
      final inBlobPtr = _localAlloc(
        _lmemZeroInit,
        sizeOf<_DataBlob>(),
      ).cast<_DataBlob>();
      final inDataPtr = _localAlloc(
        _lmemZeroInit,
        utf8Bytes.length,
      ).cast<Uint8>();
      final outBlobPtr = _localAlloc(
        _lmemZeroInit,
        sizeOf<_DataBlob>(),
      ).cast<_DataBlob>();

      try {
        final inDataList = inDataPtr.asTypedList(utf8Bytes.length);
        inDataList.setAll(0, utf8Bytes);

        inBlobPtr.ref.cbData = utf8Bytes.length;
        inBlobPtr.ref.pbData = inDataPtr;

        final res = _cryptProtectData(
          inBlobPtr,
          nullptr,
          nullptr,
          nullptr,
          nullptr,
          _cryptprotectUiForbidden,
          outBlobPtr,
        );

        if (res != 0) {
          final outLen = outBlobPtr.ref.cbData;
          final outDataPtr = outBlobPtr.ref.pbData;
          final outBytes = Uint8List.fromList(outDataPtr.asTypedList(outLen));

          _localFree(outDataPtr.cast<Void>());
          return '$prefix${base64Encode(outBytes)}';
        }
      } finally {
        _localFree(inDataPtr.cast<Void>());
        _localFree(inBlobPtr.cast<Void>());
        _localFree(outBlobPtr.cast<Void>());
      }
    } catch (_) {
      // Fallback on error
    }
    return plainText;
  }

  /// Decrypts DPAPI ciphertext prefixed with `dpapi:<base64>`.
  /// If input does not start with `dpapi:`, returns [cipherText] directly.
  static String decrypt(String cipherText) {
    if (!cipherText.startsWith(prefix)) return cipherText;
    if (!isSupported) return cipherText;

    try {
      final base64Str = cipherText.substring(prefix.length);
      final cipherBytes = base64Decode(base64Str);

      final inBlobPtr = _localAlloc(
        _lmemZeroInit,
        sizeOf<_DataBlob>(),
      ).cast<_DataBlob>();
      final inDataPtr = _localAlloc(
        _lmemZeroInit,
        cipherBytes.length,
      ).cast<Uint8>();
      final outBlobPtr = _localAlloc(
        _lmemZeroInit,
        sizeOf<_DataBlob>(),
      ).cast<_DataBlob>();

      try {
        final inDataList = inDataPtr.asTypedList(cipherBytes.length);
        inDataList.setAll(0, cipherBytes);

        inBlobPtr.ref.cbData = cipherBytes.length;
        inBlobPtr.ref.pbData = inDataPtr;

        final res = _cryptUnprotectData(
          inBlobPtr,
          nullptr,
          nullptr,
          nullptr,
          nullptr,
          _cryptprotectUiForbidden,
          outBlobPtr,
        );

        if (res != 0) {
          final outLen = outBlobPtr.ref.cbData;
          final outDataPtr = outBlobPtr.ref.pbData;
          final outBytes = Uint8List.fromList(outDataPtr.asTypedList(outLen));

          _localFree(outDataPtr.cast<Void>());
          return utf8.decode(outBytes);
        }
      } finally {
        _localFree(inDataPtr.cast<Void>());
        _localFree(inBlobPtr.cast<Void>());
        _localFree(outBlobPtr.cast<Void>());
      }
    } catch (_) {
      // Fallback on error
    }
    return cipherText;
  }
}
