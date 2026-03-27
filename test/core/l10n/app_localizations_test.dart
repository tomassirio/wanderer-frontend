import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations - English', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = AppLocalizations('en');
    });

    test('returns English sidebar labels', () {
      expect(l10n.trips, 'Trips');
      expect(l10n.tripPlans, 'Trip Plans');
      expect(l10n.friends, 'Friends');
      expect(l10n.achievements, 'Achievements');
      expect(l10n.buyMeACoffee, 'Buy Me a Coffee');
      expect(l10n.logout, 'Logout');
      expect(l10n.logIn, 'Log In / Sign Up');
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
      l10n = AppLocalizations('es');
    });

    test('returns Spanish sidebar labels', () {
      expect(l10n.trips, 'Viajes');
      expect(l10n.tripPlans, 'Planes de Viaje');
      expect(l10n.friends, 'Amigos');
      expect(l10n.achievements, 'Logros');
      expect(l10n.buyMeACoffee, 'Cómprame un Café');
      expect(l10n.logout, 'Cerrar Sesión');
      expect(l10n.logIn, 'Iniciar Sesión / Registrarse');
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

  group('AppLocalizations - French', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = AppLocalizations('fr');
    });

    test('returns French sidebar labels', () {
      expect(l10n.trips, 'Voyages');
      expect(l10n.tripPlans, 'Plans de Voyage');
      expect(l10n.friends, 'Amis');
      expect(l10n.achievements, 'Réalisations');
      expect(l10n.logout, 'Déconnexion');
      expect(l10n.logIn, 'Se Connecter / S\'inscrire');
      expect(l10n.guest, 'Invité');
      expect(l10n.settings, 'Paramètres');
    });

    test('returns French common action labels', () {
      expect(l10n.cancel, 'Annuler');
      expect(l10n.delete, 'Supprimer');
      expect(l10n.save, 'Enregistrer');
      expect(l10n.retry, 'Réessayer');
    });

    test('returns French status labels', () {
      expect(l10n.allStatus, 'Tous les Statuts');
      expect(l10n.live, 'En Direct');
      expect(l10n.paused, 'En Pause');
      expect(l10n.completed, 'Terminé');
      expect(l10n.draft, 'Brouillon');
    });
  });

  group('AppLocalizations - Dutch', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = AppLocalizations('nl');
    });

    test('returns Dutch sidebar labels', () {
      expect(l10n.trips, 'Reizen');
      expect(l10n.tripPlans, 'Reisplannen');
      expect(l10n.friends, 'Vrienden');
      expect(l10n.achievements, 'Prestaties');
      expect(l10n.logout, 'Uitloggen');
      expect(l10n.logIn, 'Inloggen / Registreren');
      expect(l10n.guest, 'Gast');
      expect(l10n.settings, 'Instellingen');
    });

    test('returns Dutch common action labels', () {
      expect(l10n.cancel, 'Annuleren');
      expect(l10n.delete, 'Verwijderen');
      expect(l10n.save, 'Opslaan');
      expect(l10n.retry, 'Opnieuw proberen');
    });

    test('returns Dutch status labels', () {
      expect(l10n.allStatus, 'Alle Statussen');
      expect(l10n.live, 'Live');
      expect(l10n.paused, 'Gepauzeerd');
      expect(l10n.completed, 'Voltooid');
      expect(l10n.draft, 'Concept');
    });
  });

  group('AppLocalizations - fallback', () {
    test('unknown language falls back to English', () {
      final l10n = AppLocalizations('xx');
      expect(l10n.trips, 'Trips');
      expect(l10n.cancel, 'Cancel');
    });
  });

  group('AppLocalizations - language names', () {
    test('returns native language names', () {
      final l10n = AppLocalizations('en');
      expect(l10n.languageNameFor('en'), 'English');
      expect(l10n.languageNameFor('es'), 'Español');
      expect(l10n.languageNameFor('fr'), 'Français');
      expect(l10n.languageNameFor('nl'), 'Nederlands');
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
