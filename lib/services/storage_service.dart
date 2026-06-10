import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Per debugPrint
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Risultato dell'operazione di upload
class UploadResult {
  final String? url;
  final String? errorMessage;
  bool get isSuccess => url != null;

  UploadResult({this.url, this.errorMessage});
}

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Carica un'immagine su Firebase Storage applicando una compressione automatica.
  Future<UploadResult> uploadImage(XFile imageFile, String path) async {
    try {
      debugPrint('Inizio processo di upload per: $path');
      
      final Uint8List originalBytes = await imageFile.readAsBytes();
      
      // 1. Comprimiamo l'immagine per risparmiare banda
      final Uint8List dataToUpload = await _compressImage(originalBytes);

      // 2. Assicuriamo l'estensione corretta (.jpg)
      final String safePath = _ensureJpegExtension(path);

      // 3. Esecuzione dell'upload
      final ref = _storage.ref().child(safePath);
      final uploadTask = await ref.putData(
        dataToUpload,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // 4. Ottenimento URL pubblico
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('Upload completato. URL: $downloadUrl');
      
      return UploadResult(url: downloadUrl);
      
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage Error: ${e.code} - ${e.message}');
      return UploadResult(errorMessage: 'Errore di rete: Impossibile caricare l\'immagine.');
    } catch (e) {
      debugPrint('Imprevisto durante l\'upload: $e');
      return UploadResult(errorMessage: 'Si è verificato un errore inaspettato.');
    }
  }

  /// Tenta di comprimere i byte dell'immagine. Se fallisce (es. su Web), 
  /// restituisce i byte originali come fallback.
  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      final compressedData = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      
      // Ritorna i dati compressi solo se l'operazione è andata a buon fine
      return compressedData.isNotEmpty ? compressedData : bytes;
    } catch (e) {
      debugPrint('Attenzione: Compressione fallita (potrebbe essere Flutter Web). Uso i byte originali. Dettaglio: $e');
      return bytes;
    }
  }

  /// Pulisce il percorso assicurandosi che termini con .jpg
  /// Sostituisce eventuali altre estensioni (es. .png, .gif) con .jpg
  String _ensureJpegExtension(String path) {
    final lowerPath = path.toLowerCase();
    
    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
      return path;
    }
    
    // Trova l'ultimo punto nel nome del file per sostituire l'estensione esistente
    final lastDotIndex = path.lastIndexOf('.');
    if (lastDotIndex != -1 && (path.length - lastDotIndex) <= 5) {
      // Es: "avatar.png" -> "avatar.jpg"
      return '${path.substring(0, lastDotIndex)}.jpg';
    }
    
    // Se non c'era estensione, la aggiungiamo semplicemente
    return '$path.jpg';
  }
}
