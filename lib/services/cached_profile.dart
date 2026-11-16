import 'package:cloud_firestore/cloud_firestore.dart';

Future<DocumentSnapshot<Map<String, dynamic>>?> readCachedProfile(
    FirebaseFirestore db, String uid) async {
  if (uid.isEmpty) return null;
  try {
    return await db
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.cache));
  } on FirebaseException {
    return null; // Cache miss/unavailable: wait for the authoritative lookup.
  }
}
