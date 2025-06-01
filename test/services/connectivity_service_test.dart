import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart'; // Importar para kDebugMode
import 'package:flutter/widgets.dart'; // Importar para AppLifecycleState
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:splitup_application/services/connectivity_service.dart';

// Generar mocks para Connectivity y StreamSubscription
@GenerateMocks([Connectivity, StreamSubscription])
import 'connectivity_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectivityService connectivityService;
  late MockConnectivity mockConnectivity;
  late StreamController<List<ConnectivityResult>> connectivityStreamController;

  // Helper para crear una instancia de ConnectivityService con un mock
  ConnectivityService createMockedService(Connectivity connectivity) {
    // Usar el nuevo método estático para establecer la instancia con el mock
    ConnectivityService.setInstanceForTest(connectivity);
    // Obtener la instancia recién establecida a través del getter público
    return ConnectivityService.instance;
  }

  setUp(() {
    mockConnectivity = MockConnectivity();
    connectivityStreamController = StreamController<List<ConnectivityResult>>.broadcast();

    when(mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityStreamController.stream);
    when(mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);

    connectivityService = createMockedService(mockConnectivity);
  });

  tearDown(() {
    connectivityService.dispose();
    if (!connectivityStreamController.isClosed) {
      connectivityStreamController.close();
    }
  });

  group('ConnectivityService Tests', () {
    test('Initial state is determined by checkConnectivity', () async {
      when(mockConnectivity.checkConnectivity()).thenAnswer((_) async => [ConnectivityResult.wifi]);
      final serviceWithWifi = createMockedService(mockConnectivity);
      await serviceWithWifi.checkConnectivity();
      expect(serviceWithWifi.hasConnection, isTrue);
      serviceWithWifi.dispose();

      when(mockConnectivity.checkConnectivity()).thenAnswer((_) async => [ConnectivityResult.none]);
      final serviceWithNone = createMockedService(mockConnectivity);
      await serviceWithNone.checkConnectivity();
      expect(serviceWithNone.hasConnection, isFalse);
      serviceWithNone.dispose();
      
      when(mockConnectivity.checkConnectivity()).thenThrow(Exception('Connectivity check failed'));
      final serviceWithError = createMockedService(mockConnectivity);
      await serviceWithError.checkConnectivity();
      expect(serviceWithError.hasConnection, isFalse);
      serviceWithError.dispose();
    });

    test('hasConnection updates and connectionStream emits on connectivity change', () async {
      await connectivityService.checkConnectivity(); 
      expect(connectivityService.hasConnection, isTrue);

      final futureDisconnected = connectivityService.connectionStream.firstWhere((status) => status == false);
      connectivityStreamController.add([ConnectivityResult.none]);
      await futureDisconnected;
      expect(connectivityService.hasConnection, isFalse);

      final futureConnectedMobile = connectivityService.connectionStream.firstWhere((status) => status == true);
      connectivityStreamController.add([ConnectivityResult.mobile]);
      await futureConnectedMobile;
      expect(connectivityService.hasConnection, isTrue);
      
      final futureConnectedEthernet = connectivityService.connectionStream.firstWhere((status) => status == true);
      connectivityStreamController.add([ConnectivityResult.ethernet]);
      await futureConnectedEthernet;
      expect(connectivityService.hasConnection, isTrue);
    });

    test('No notification if connectivity state does not change', () async {
      await connectivityService.checkConnectivity(); 
      expect(connectivityService.hasConnection, isTrue);

      bool streamNotified = false;
      final sub = connectivityService.connectionStream.listen((_) {
        streamNotified = true;
      });

      connectivityStreamController.add([ConnectivityResult.wifi]);
      await Future.delayed(Duration.zero); 

      expect(streamNotified, isFalse, reason: "Stream should not notify if status hasn't changed");
      expect(connectivityService.hasConnection, isTrue);

      sub.cancel();
    });
    
    test('_processConnectivityResult handles empty list as no connection', () async {
      final service = createMockedService(mockConnectivity);
      when(mockConnectivity.checkConnectivity()).thenAnswer((_) async => [ConnectivityResult.wifi]);
      await service.checkConnectivity();
      expect(service.hasConnection, isTrue);

      final futureBecomesFalse = service.connectionStream.firstWhere((status) => status == false);
      connectivityStreamController.add([]); 
      
      await futureBecomesFalse;
      expect(service.hasConnection, isFalse);
      service.dispose();
    });

    test('_processConnectivityResult handles various results correctly', () async {
      final service = createMockedService(mockConnectivity);

      Future<void> checkTransition(List<ConnectivityResult> startResult, List<ConnectivityResult> endResult, bool expectedConnection) async {
        when(mockConnectivity.checkConnectivity()).thenAnswer((_) async => startResult);
        await service.checkConnectivity(); // Establecer estado inicial conocido
        
        final completer = Completer<void>();
        final sub = service.connectionStream.listen((status) {
          if (status == expectedConnection && !completer.isCompleted) {
            completer.complete();
          }
        });

        connectivityStreamController.add(endResult);
        await completer.future.timeout(const Duration(seconds: 1), onTimeout: () {
          // Si hay timeout, significa que el stream no emitió el valor esperado.
          // Esto puede pasar si el estado ya era el `expectedConnection` y no hubo cambio real.
          if (service.hasConnection != expectedConnection) {
            throw TimeoutException("Stream did not emit $expectedConnection in time for $endResult");
          }
        });
        expect(service.hasConnection, expectedConnection, reason: "Failed for $endResult");
        await sub.cancel();
      }

      await checkTransition([ConnectivityResult.none], [ConnectivityResult.wifi], true); // none -> wifi = true
      await checkTransition([ConnectivityResult.wifi], [ConnectivityResult.mobile], true); // wifi -> mobile = true
      await checkTransition([ConnectivityResult.mobile], [ConnectivityResult.ethernet], true); // mobile -> ethernet = true
      await checkTransition([ConnectivityResult.ethernet], [ConnectivityResult.bluetooth], true); // ethernet -> bluetooth = true
      await checkTransition([ConnectivityResult.bluetooth], [ConnectivityResult.none], false); // bluetooth -> none = false
      await checkTransition([ConnectivityResult.none], [ConnectivityResult.wifi, ConnectivityResult.none], true); // none -> [wifi, none] = true
      await checkTransition([ConnectivityResult.wifi, ConnectivityResult.none], [ConnectivityResult.other], true); // [wifi, none] -> other = true
      await checkTransition([ConnectivityResult.other], [], false); // other -> [] = false
      
      service.dispose();
    });

    test('dispose cancels subscription and closes stream controller', () async {
      final service = createMockedService(mockConnectivity);
      
      expect(connectivityStreamController.hasListener, isTrue);

      service.dispose();

      expect(connectivityStreamController.hasListener, isFalse, reason: "Subscription should be cancelled on dispose");
      expect(() => service.connectionStream.listen(null), throwsA(isA<StateError>()), reason: "Stream controller should be closed");
    });

    test('didChangeAppLifecycleState triggers checkConnectivity on resume', () async {
      final service = createMockedService(mockConnectivity);
      // La llamada inicial a checkConnectivity ocurre dentro de _initializeService,
      // que es llamado por el constructor _internal.
      // Esperamos a que esa llamada inicial se complete.
      await untilCalled(mockConnectivity.checkConnectivity());
      // Limpiamos las interacciones de esta llamada inicial para no interferir con la verificación de 'resumed'.
      clearInteractions(mockConnectivity);

      // Configuramos la respuesta para futuras llamadas a checkConnectivity.
      when(mockConnectivity.checkConnectivity()).thenAnswer((_) async => [ConnectivityResult.wifi]);
      
      // Simular evento de ciclo de vida: resumed
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      // Esperar a que se complete la llamada asíncrona a checkConnectivity disparada por 'resumed'.
      await untilCalled(mockConnectivity.checkConnectivity()); 
      // Verificar que checkConnectivity fue llamado exactamente una vez debido al 'resume'.
      verify(mockConnectivity.checkConnectivity()).called(1);
      
      // Simular otros estados para asegurarse de que no llaman a checkConnectivity
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.didChangeAppLifecycleState(AppLifecycleState.inactive);
      // En Flutter < 3.13, AppLifecycleState.detached. En >= 3.13, es AppLifecycleState.hidden.
      // Usamos detached por ahora, ajustar si la versión de Flutter es más reciente.
      service.didChangeAppLifecycleState(AppLifecycleState.detached);
      
      // Verificar que checkConnectivity no fue llamado más veces después de los otros estados.
      // Como ya verificamos que se llamó 1 vez por 'resume', y no debería haberse llamado por los otros,
      // el conteo total de llamadas (después de limpiar las interacciones iniciales) debe seguir siendo 1.
      verify(mockConnectivity.checkConnectivity()).called(1);

      service.dispose();
    });
    
    test('Error in connectivity stream is handled', () async {
      final service = createMockedService(mockConnectivity);
      await service.checkConnectivity();

      final error = Exception('Connectivity stream error');
      connectivityStreamController.addError(error);
      await Future.delayed(Duration.zero); 
      
      expect(service.hasConnection, isTrue); 
      
      final expectation = expectLater(service.connectionStream, emits(false));
      connectivityStreamController.add([ConnectivityResult.none]);
      await expectation;
      expect(service.hasConnection, isFalse);

      service.dispose();
    });
  });
}

// Necesitarás ejecutar `flutter pub run build_runner build --delete-conflicting-outputs` para generar `connectivity_service_test.mocks.dart`
// después de añadir la anotación @GenerateMocks y el import.

// Clase de ayuda para mockear StreamSubscription si fuera necesario verificar `cancel()`
// class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}
