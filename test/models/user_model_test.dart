import 'package:flutter_test/flutter_test.dart';
import 'package:splitup_application/models/user_model.dart';

void main() {
  group('UserModel', () {
    // Test para el constructor
    test('constructor creates a UserModel instance', () {
      final user = UserModel(
        id: '1',
        name: 'Test User',
        email: 'test@example.com',
        photoUrl: 'http://example.com/photo.jpg',
      );

      expect(user.id, '1');
      expect(user.name, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.photoUrl, 'http://example.com/photo.jpg');
    });

    // Test para el constructor con photoUrl nulo
    test('constructor creates a UserModel instance with null photoUrl', () {
      final user = UserModel(
        id: '2',
        name: 'Another User',
        email: 'another@example.com',
        // photoUrl no se proporciona, debería ser nulo
      );

      expect(user.id, '2');
      expect(user.name, 'Another User');
      expect(user.email, 'another@example.com');
      expect(user.photoUrl, isNull);
    });

    // Test para el factory UserModel.fromMap
    group('fromMap', () {
      test('creates a UserModel from a map', () {
        final map = {
          'name': 'Map User',
          'email': 'map@example.com',
          'photoUrl': 'http://example.com/map_photo.jpg',
        };
        final user = UserModel.fromMap(map, '3');

        expect(user.id, '3');
        expect(user.name, 'Map User');
        expect(user.email, 'map@example.com');
        expect(user.photoUrl, 'http://example.com/map_photo.jpg');
      });

      test('handles missing photoUrl in map', () {
        final map = {
          'name': 'NoPhoto User',
          'email': 'nophoto@example.com',
        };
        final user = UserModel.fromMap(map, '4');

        expect(user.id, '4');
        expect(user.name, 'NoPhoto User');
        expect(user.email, 'nophoto@example.com');
        expect(user.photoUrl, isNull);
      });

      test('handles null values in map for name and email by defaulting to empty strings', () {
        final map = {
          'name': null,
          'email': null,
          'photoUrl': null,
        };
        final user = UserModel.fromMap(map, '5');

        expect(user.id, '5');
        expect(user.name, ''); // Debería ser cadena vacía
        expect(user.email, ''); // Debería ser cadena vacía
        expect(user.photoUrl, isNull);
      });
       test('handles completely empty map by defaulting to empty strings for name and email', () {
        final Map<String, dynamic> map = {};
        final user = UserModel.fromMap(map, '6');

        expect(user.id, '6');
        expect(user.name, ''); // Debería ser cadena vacía
        expect(user.email, ''); // Debería ser cadena vacía
        expect(user.photoUrl, isNull);
      });
    });

    // Test para el método toMap
    group('toMap', () {
      test('converts a UserModel to a map', () {
        final user = UserModel(
          id: '7',
          name: 'ToMap User',
          email: 'tomap@example.com',
          photoUrl: 'http://example.com/tomap_photo.jpg',
        );
        final map = user.toMap();

        expect(map['name'], 'ToMap User');
        expect(map['email'], 'tomap@example.com');
        expect(map['photoUrl'], 'http://example.com/tomap_photo.jpg');
        // El ID no se incluye en toMap, lo cual es correcto para Firestore
        // si el ID es el nombre del documento.
        expect(map.containsKey('id'), isFalse);
      });

      test('handles null photoUrl when converting to map', () {
        final user = UserModel(
          id: '8',
          name: 'ToMap NoPhoto User',
          email: 'tomapnophoto@example.com',
        );
        final map = user.toMap();

        expect(map['name'], 'ToMap NoPhoto User');
        expect(map['email'], 'tomapnophoto@example.com');
        expect(map['photoUrl'], isNull);
      });
    });
  });
}
