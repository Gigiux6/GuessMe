import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart';
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

  /// Carica un'immagine su Firebase Storage dopo averla compressa.
  /// 
  /// [imageFile] L'XFile dell'immagine da caricare (compatibile con Web e Mobile).
  /// [path] Il percorso di destinazione su Firebase Storage (es: 'avatars/user123.jpg').
  Future<UploadResult> uploadImage(XFile imageFile, String path) async {
    try {
      // Leggiamo i byte del file (funziona su tutte le piattaforme)
      print('DEBUG: Inizio lettura bytes...');
      final Uint8List bytes = await imageFile.readAsBytes();
      print('DEBUG: Bytes letti: ${bytes.length}');

      // 1. Compressione dell'immagine
      Uint8List? compressedData;
      
      try {
        print('DEBUG: Inizio compressione...');
        compressedData = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1024,
          minHeight: 1024,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        print('DEBUG: Compressione completata. Dimensione: ${compressedData?.length}');
      } catch (e) {
        print('DEBUG: Errore compressione: $e');
        compressedData = bytes;
      }

      if (compressedData == null) {
        return UploadResult(errorMessage: 'Impossibile processare l\'immagine.');
      }

      // 2. Caricamento su Firebase Storage
      String finalPath = path;
      if (!finalPath.toLowerCase().endsWith('.jpg') && !finalPath.toLowerCase().endsWith('.jpeg')) {
        finalPath = '$finalPath.jpg';
      }

      print('DEBUG: Inizio upload su path: $finalPath');
      final ref = _storage.ref().child(finalPath);
      
      final uploadTask = ref.putData(
        compressedData,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Aggiungiamo un listener per vedere il progresso o eventuali errori immediati
      uploadTask.snapshotEvents.listen(
        (event) {
          print('DEBUG Upload: ${event.bytesTransferred}/${event.totalBytes} (${(event.bytesTransferred/event.totalBytes*100).toStringAsFixed(1)}%)');
        },
        onError: (e) {
          print('DEBUG: Errore nello stream di upload: $e');
        }
      );

      final snapshot = await uploadTask;
      print('DEBUG: Upload completato con successo.');
      
      // 3. Recupero dell'URL pubblico
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('DEBUG: URL ottenuto: $downloadUrl');
      
      return UploadResult(url: downloadUrl);
      
    } on FirebaseException catch (e) {
      return UploadResult(errorMessage: 'Errore Firebase: ${e.message}');
    } catch (e) {
      return UploadResult(errorMessage: 'Errore imprevisto durante l\'upload: $e');
    }
  }
}
