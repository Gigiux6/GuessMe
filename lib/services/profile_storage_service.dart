import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class ProfileStorageService {
  final FirebaseStorage _storage;
  final ImagePicker _picker;
  final ImageCropper _cropper;

  // 1. Dependency Injection
  ProfileStorageService({
    FirebaseStorage? storage,
    ImagePicker? picker,
    ImageCropper? cropper,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker(),
        _cropper = cropper ?? ImageCropper();

  /// Consente all'utente di selezionare un'immagine dalla galleria del telefono.
  Future<XFile?> pickImageFromGallery() async {
    try {
      return await _picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      debugPrint('Errore durante la selezione dell\'immagine: $e');
      rethrow;
    }
  }

  /// Consente all'utente di ritagliare l'immagine in formato 1:1 con un'anteprima circolare.
  Future<CroppedFile?> cropImage({
    required XFile imageFile,
    BuildContext? context,
    String title = 'Ritaglia',
    String cropText = 'Conferma',
    String cancelText = 'Annulla',
    String rotateLeftText = 'Ruota a Sinistra',
    String rotateRightText = 'Ruota a Destra',
  }) async {
    try {
      return await _cropper.cropImage(
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
    } catch (e) {
      debugPrint('Errore durante il ritaglio: $e');
      return null;
    }
  }

  /// Ottimizza, ridimensiona e carica l'immagine profilo dell'utente su Firebase Storage.
  Future<String> uploadProfileImage(CroppedFile imageFile, String userId) async {
    return _compressAndUpload(
      bytes: await imageFile.readAsBytes(),
      path: 'profiles/$userId.jpg',
      minWidth: 400,
      minHeight: 400,
      quality: 70,
    );
  }

  /// Uploads a custom image (e.g., for custom game mode) maintaining high quality and aspect ratio.
  Future<String> uploadCustomImage(XFile file, String identifier) async {
    return _compressAndUpload(
      bytes: await file.readAsBytes(),
      path: identifier,
      minWidth: 1080,
      minHeight: 1080,
      quality: 85,
    );
  }

  /// Metodo privato centralizzato per la compressione e upload (Principio DRY)
  Future<String> _compressAndUpload({
    required Uint8List bytes,
    required String path,
    required int minWidth,
    required int minHeight,
    required int quality,
  }) async {
    try {
      Uint8List compressedData;
      try {
        compressedData = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: minWidth,
          minHeight: minHeight,
          quality: quality,
          format: CompressFormat.jpeg,
        );
      } catch (compressError) {
        debugPrint('Fallback ai byte originali causa errore compressione: $compressError');
        compressedData = bytes;
      }

      final Reference ref = _storage.ref().child(path);
      final UploadTask uploadTask = ref.putData(
        compressedData,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Errore fatale in upload su $path: $e');
      rethrow;
    }
  }

  /// Elimina tutte le immagini personalizzate associate a una determinata stanza.
  Future<void> deleteCustomRoomImages(String roomId) async {
    try {
      final ListResult result = await _storage.ref('custom_identities/$roomId').listAll();
      await Future.wait(result.items.map((ref) => ref.delete())); // Esecuzione parallela
      debugPrint('Eliminate tutte le immagini personalizzate per la stanza $roomId');
    } catch (e) {
      debugPrint('Errore durante l\'eliminazione delle immagini personalizzate: $e');
    }
  }
}
