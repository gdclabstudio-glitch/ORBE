import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class ContentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 1. Buscar as configurações gerais do evento do Firestore
  Future<Map<String, dynamic>> fetchEventConfig() async {
    try {
      final doc =
          await _firestore.collection('site_config').doc('event_details').get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
      // Retorna valores padrão caso o documento ainda não exista
      return {
        'title': 'ORBE • A COMUNIDADE EM MOVIMENTO',
        'date': '05 de Fevereiro de 2027',
        'location': 'Peçanha - MG',
      };
    } catch (e) {
      debugPrint('Erro ao buscar configurações: $e');
      rethrow;
    }
  }

  // 2. Salvar/Atualizar as configurações gerais do evento
  Future<void> updateEventConfig(Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('site_config')
          .doc('event_details')
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Erro ao salvar configurações: $e');
      rethrow;
    }
  }

  // 3. Fazer upload de mídias (imagens, banners) para o Firebase Storage
  Future<String> uploadMedia(Uint8List fileBytes, String fileName) async {
    try {
      final ref = _storage.ref().child('site_assets/$fileName');

      // Metadados para garantir o tipo correto na web e mobile
      final metadata = SettableMetadata(contentType: 'image/png');

      final uploadTask = await ref.putData(fileBytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Erro no upload para o Storage: $e');
      rethrow;
    }
  }

  // 4. Salvar referência da imagem da galeria no Firestore
  Future<void> updateGalleryItem(
    String year,
    String imageUrl,
    String tag,
  ) async {
    try {
      await _firestore.collection('gallery').doc(year).set({
        'year': year,
        'url': imageUrl,
        'tag': tag,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Erro ao atualizar galeria: $e');
      rethrow;
    }
  }
}
