import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations - English', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = const AppLocalizations('en');
    });

    test('returns English sidebar labels', () {
      expect(l10n.trips, 'Trips');
      expect(l10n.tripPlans, 'Trip Plans');
      expect(l10n.friends, 'Friends');
      expect(l10n.achievements, 'Achievements');
      expect(l10n.buyMeACoffee, 'Buy Me a Coffee');
      expect(l10n.logout, 'Logout');
      expect(l10n.logIn, 'Log In');
      expect(l10n.guest, 'Guest');
      expect(l10n.myProfile, 'My Profile');
      expect(l10n.settings, 'Settings');
      expect(l10n.tripPromotion, 'Trip Promotion');
      expect(l10n.userManagement, 'User Management');
      expect(l10n.tripDataMaintenance, 'Trip Data Maintenance');
    });

    test('returns English common action labels', () {
      expect(l10n.cancel, 'Cancel');
      expect(l10n.delete, 'Delete');
      expect(l10n.save, 'Save');
      expect(l10n.retry, 'Retry');
    });

    test('returns English status labels', () {
      expect(l10n.allStatus, 'All Status');
      expect(l10n.live, 'Live');
      expect(l10n.paused, 'Paused');
      expect(l10n.completed, 'Completed');
      expect(l10n.draft, 'Draft');
    });

    test('returns English visibility labels', () {
      expect(l10n.allVisibility, 'All Visibility');
      expect(l10n.publicVisibility, 'Public');
      expect(l10n.protectedVisibility, 'Protected');
      expect(l10n.privateVisibility, 'Private');
    });

    test('returns English home screen labels', () {
      expect(l10n.newTrip, 'New Trip');
      expect(l10n.deleteTrip, 'Delete Trip');
    });
  });

  group('AppLocalizations - Spanish', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = const AppLocalizations('es');
    });

    test('returns Spanish sidebar labels', () {
      expect(l10n.trips, 'Viajes');
      expect(l10n.tripPlans, 'Planes de Viaje');
      expect(l10n.friends, 'Amigos');
      expect(l10n.achievements, 'Logros');
      expect(l10n.buyMeACoffee, 'Cómprame un Café');
      expect(l10n.logout, 'Cerrar Sesión');
      expect(l10n.logIn, 'Iniciar Sesión');
      expect(l10n.guest, 'Invitado');
      expect(l10n.myProfile, 'Mi Perfil');
      expect(l10n.settings, 'Configuración');
      expect(l10n.tripPromotion, 'Promoción de Viajes');
      expect(l10n.userManagement, 'Gestión de Usuarios');
      expect(l10n.tripDataMaintenance, 'Mantenimiento de Datos');
    });

    test('returns Spanish common action labels', () {
      expect(l10n.cancel, 'Cancelar');
      expect(l10n.delete, 'Eliminar');
      expect(l10n.save, 'Guardar');
      expect(l10n.retry, 'Reintentar');
    });

    test('returns Spanish status labels', () {
      expect(l10n.allStatus, 'Todos los Estados');
      expect(l10n.live, 'En Vivo');
      expect(l10n.paused, 'Pausado');
      expect(l10n.completed, 'Completado');
      expect(l10n.draft, 'Borrador');
    });

    test('returns Spanish visibility labels', () {
      expect(l10n.allVisibility, 'Toda Visibilidad');
      expect(l10n.publicVisibility, 'Público');
      expect(l10n.protectedVisibility, 'Protegido');
      expect(l10n.privateVisibility, 'Privado');
    });

    test('returns Spanish home screen labels', () {
      expect(l10n.newTrip, 'Nuevo Viaje');
      expect(l10n.deleteTrip, 'Eliminar Viaje');
    });
  });

  group('AppLocalizations - fromController', () {
    test('creates instance from controller locale', () {
      final l10n = AppLocalizations.fromController();
      // Default locale is English
      expect(l10n.trips, 'Trips');
    });
  });
}
