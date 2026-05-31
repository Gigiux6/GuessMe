import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class ProfileStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final ImageCropper _cropper = ImageCropper();



  /// Consente all'utente di selezionare un'immagine dalla galleria del telefono.
  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      return image;
    } catch (e) {
      debugPrint('Errore durante la selezione dell\'immagine: $e');
      rethrow;
    }
  }

  /// Consente all'utente di ritagliare l'immagine in formato 1:1 con un'anteprima circolare.
  Future<CroppedFile?> cropImage(XFile imageFile, BuildContext context) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final String title = userProvider.t('crop_title');
      final String cropText = userProvider.t('crop');
      final String cancelText = userProvider.t('cancel');
      final String rotateLeftText = userProvider.t('rotate_left');
      final String rotateRightText = userProvider.t('rotate_right');

      final croppedFile = await _cropper.cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: title,
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: title,
            doneButtonTitle: cropText,
            cancelButtonTitle: cancelText,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 400, height: 400),
            translations: WebTranslations(
              title: title,
              rotateLeftTooltip: rotateLeftText,
              rotateRightTooltip: rotateRightText,
              cancelButton: cancelText,
              cropButton: cropText,
            ),
          ),
        ],
      );
      return croppedFile;
    } catch (e) {
      debugPrint('Errore durante il ritaglio: $e');
      return null;
    }
  }

  /// Ottimizza, ridimensiona e carica l'immagine profilo dell'utente su Firebase Storage.
  /// 
  /// - Risoluzione finale: esattamente 400x400 pixel.
  /// - Formato: JPEG con qualità impostata a 70.
  /// - Percorso di upload: `profiles/${userId}.jpg`.
  /// 
  /// Ritorna l'URL pubblico del file caricato.
  Future<String> uploadProfileImage(CroppedFile imageFile, String userId) async {
    try {
      debugPrint('DEBUG ProfileStorage: Inizio lettura bytes...');
      final Uint8List bytes = await imageFile.readAsBytes();
      debugPrint('DEBUG ProfileStorage: Bytes letti: ${bytes.length}');

      // 1. Ottimizzazione e compressione
      Uint8List compressedData;
      try {
        debugPrint('DEBUG ProfileStorage: Inizio compressione a 400x400...');
        final result = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 400,
          minHeight: 400,
          quality: 70,
          format: CompressFormat.jpeg,
        );
        compressedData = result;
        debugPrint('DEBUG ProfileStorage: Compressione completata. Dimensione: ${compressedData.length} bytes');
      } catch (compressError) {
        // Se la compressione fallisce (es. su Web o errore nativo), usiamo i byte originali come fallback
        debugPrint('DEBUG ProfileStorage: Compressione fallita ($compressError). Uso i bytes originali.');
        compressedData = bytes;
      }

      // 2. Definizione del percorso e metadati (profiles/${userId}.jpg)
      final String path = 'profiles/$userId.jpg';
      debugPrint('DEBUG ProfileStorage: Inizio upload su path: $path');
      final Reference ref = _storage.ref().child(path);
      
      final UploadTask uploadTask = ref.putData(
        compressedData,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      debugPrint('DEBUG ProfileStorage: Caricamento completato con successo.');

      // 3. Recupero dell'URL pubblico
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('DEBUG ProfileStorage: URL pubblico ottenuto: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      debugPrint('Errore durante l\'ottimizzazione/caricamento dell\'immagine: $e');
      rethrow;
    }
  }

  /// Uploads a custom image (e.g., for custom game mode) maintaining high quality and aspect ratio.
  /// The identifier is the full storage path without the leading slash, e.g.,
  /// 'custom_identities/{roomId}/{playerId}.jpg'.
  Future<String> uploadCustomImage(XFile file, String identifier) async {
    try {
      // Read bytes from the file
      final Uint8List bytes = await file.readAsBytes();

      // Compress to high-resolution (max 1080px in either dimension) keeping aspect ratio
      Uint8List compressedData;
      try {
        final result = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1080,
          minHeight: 1080,
          quality: 85,
          format: CompressFormat.jpeg,
        );
        compressedData = result;
      } catch (compressError) {
        // Fallback to original bytes if compression fails
        compressedData = bytes;
      }

      // Upload to the provided identifier path
      final Reference ref = _storage.ref().child(identifier);
      final UploadTask uploadTask = ref.putData(
        compressedData,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final TaskSnapshot snapshot = await uploadTask;
      // Return the public download URL
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading custom image: $e');
      rethrow;
    }
  }

  /// Elimina tutte le immagini personalizzate associate a una determinata stanza.
  Future<void> deleteCustomRoomImages(String roomId) async {
    try {
      final ListResult result = await _storage.ref('custom_identities/$roomId').listAll();
      for (final Reference ref in result.items) {
        await ref.delete();
      }
      debugPrint('DEBUG ProfileStorage: Eliminate tutte le immagini personalizzate per la stanza $roomId');
    } catch (e) {
      debugPrint('Errore durante l\'eliminazione delle immagini personalizzate: $e');
    }
  }

}

