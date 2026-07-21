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
      expect(l10n.welcomeToWanderer, 'Welcome to Wanderer');
      expect(l10n.trackAdventures,
          'Track trips in real time, share moments with friends, and unlock achievements.');
      expect(l10n.getStarted, 'Get Started');
      expect(l10n.trackFirstAdventure, 'Track your first adventure');
    });

    test('returns English tutorial labels', () {
      expect(l10n.tutorialSkip, 'Skip');
      expect(l10n.tutorialNext, 'Next');
      expect(l10n.tutorialMenuTitle, 'Explore the Menu');
      expect(l10n.tutorialMenuDescription,
          'Trip plans, friends, achievements, and settings all live here.');
      expect(l10n.tutorialSearchTitle, 'Find People & Trips');
      expect(l10n.tutorialSearchDescription,
          'Search for other travelers and public trips.');
      expect(l10n.tutorialNotificationsTitle, 'Stay Updated');
      expect(l10n.tutorialNotificationsDescription,
          'Get notified about comments, follows, and reactions.');
      expect(l10n.tutorialNewTripTitle, 'Start Your Adventure');
      expect(l10n.tutorialNewTripDescription,
          'Tap here to create your first trip and start tracking in real time.');
    });

    test('returns English create-trip/trip-detail tutorial labels', () {
      expect(l10n.tutorialBottomNavTitle, 'Switch Views');
      expect(l10n.tutorialBottomNavDescription,
          'Tap Discover, Feed, or My Trips to explore different views.');
      expect(l10n.tutorialTripNameTitle, 'Name Your Trip');
      expect(l10n.tutorialTripNameDescription,
          'Give your trip a title so friends can find it.');
      expect(l10n.tutorialTripTypeTitle, 'Choose Your Trip Type');
      expect(l10n.tutorialTripTypeDescription,
          'Simple for a single trip, Multi-Day for longer adventures with day markers.');
      expect(l10n.tutorialVisibilityTitle, 'Set Your Visibility');
      expect(l10n.tutorialVisibilityDescription,
          'Choose who can see this trip: public, protected, or private.');
      expect(l10n.tutorialAutoUpdatesTitle, 'Automatic Updates');
      expect(l10n.tutorialAutoUpdatesDescription,
          'Turn this on to share your location automatically at a set interval, no need to send updates manually.');
      expect(l10n.tutorialCreateButtonTitle, 'Ready to Go');
      expect(l10n.tutorialCreateButtonDescription,
          'Tap here to create your trip and start your adventure.');
      expect(l10n.tutorialSendUpdateTitle, 'Share an Update');
      expect(l10n.tutorialSendUpdateDescription,
          'Send a message or photo to update your followers in real time.');
      expect(l10n.tutorialTripStatusTitle, 'Control Your Trip');
      expect(l10n.tutorialTripStatusDescription,
          'Start, pause, or finish your trip from here.');
      expect(l10n.tutorialShareTripTitle, 'Share Your Trip');
      expect(l10n.tutorialShareTripDescription,
          'Generate a QR code or link to share this trip with others.');
      expect(l10n.tutorialInfoBubbleTitle, 'Trip Details');
      expect(l10n.tutorialInfoBubbleDescription,
          'Tap here to see trip details, follow the owner, and share this trip.');
      expect(l10n.tutorialCommentsBubbleTitle, 'Join the Conversation');
      expect(l10n.tutorialCommentsBubbleDescription,
          'Tap here to read and post comments on this trip.');
      expect(l10n.tutorialTimelineBubbleTitle, 'View the Timeline');
      expect(l10n.tutorialTimelineBubbleDescription,
          'Tap here to see the trip\'s route history and updates over time.');
      expect(l10n.tutorialSettingsBubbleTitle, 'Trip Settings');
      expect(l10n.tutorialSettingsBubbleDescription,
          'Tap here to manage automatic updates and route options for this trip.');
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
      expect(l10n.welcomeToWanderer, 'Bienvenido a Wanderer');
      expect(l10n.trackAdventures,
          'Rastrea tus viajes en tiempo real, comparte momentos con amigos y desbloquea logros.');
      expect(l10n.getStarted, 'Comenzar');
      expect(l10n.trackFirstAdventure, 'Registra tu primera aventura');
    });

    test('returns Spanish tutorial labels', () {
      expect(l10n.tutorialSkip, 'Omitir');
      expect(l10n.tutorialNext, 'Siguiente');
      expect(l10n.tutorialMenuTitle, 'Explora el Menú');
      expect(l10n.tutorialMenuDescription,
          'Planes de viaje, amigos, logros y configuración están aquí.');
      expect(l10n.tutorialSearchTitle, 'Encuentra Personas y Viajes');
      expect(l10n.tutorialSearchDescription,
          'Busca otros viajeros y viajes públicos.');
      expect(l10n.tutorialNotificationsTitle, 'Mantente Actualizado');
      expect(l10n.tutorialNotificationsDescription,
          'Recibe notificaciones de comentarios, seguidores y reacciones.');
      expect(l10n.tutorialNewTripTitle, 'Comienza Tu Aventura');
      expect(l10n.tutorialNewTripDescription,
          'Toca aquí para crear tu primer viaje y comenzar a rastrear en tiempo real.');
    });

    test('returns Spanish create-trip/trip-detail tutorial labels', () {
      expect(l10n.tutorialBottomNavTitle, 'Cambia de Vista');
      expect(l10n.tutorialBottomNavDescription,
          'Toca Descubrir, Feed o Mis Viajes para explorar diferentes vistas.');
      expect(l10n.tutorialTripNameTitle, 'Nombra Tu Viaje');
      expect(l10n.tutorialTripNameDescription,
          'Dale un título a tu viaje para que tus amigos puedan encontrarlo.');
      expect(l10n.tutorialTripTypeTitle, 'Elige el Tipo de Viaje');
      expect(l10n.tutorialTripTypeDescription,
          'Simple para un solo viaje, Multi-Día para aventuras más largas con marcadores de día.');
      expect(l10n.tutorialVisibilityTitle, 'Configura Tu Visibilidad');
      expect(l10n.tutorialVisibilityDescription,
          'Elige quién puede ver este viaje: público, protegido o privado.');
      expect(l10n.tutorialAutoUpdatesTitle, 'Actualizaciones Automáticas');
      expect(l10n.tutorialAutoUpdatesDescription,
          'Actívalo para compartir tu ubicación automáticamente en un intervalo fijo, sin necesidad de enviar actualizaciones manualmente.');
      expect(l10n.tutorialCreateButtonTitle, 'Listo para Empezar');
      expect(l10n.tutorialCreateButtonDescription,
          'Toca aquí para crear tu viaje y comenzar tu aventura.');
      expect(l10n.tutorialSendUpdateTitle, 'Comparte una Actualización');
      expect(l10n.tutorialSendUpdateDescription,
          'Envía un mensaje o foto para actualizar a tus seguidores en tiempo real.');
      expect(l10n.tutorialTripStatusTitle, 'Controla Tu Viaje');
      expect(l10n.tutorialTripStatusDescription,
          'Inicia, pausa o finaliza tu viaje desde aquí.');
      expect(l10n.tutorialShareTripTitle, 'Comparte Tu Viaje');
      expect(l10n.tutorialShareTripDescription,
          'Genera un código QR o enlace para compartir este viaje con otros.');
      expect(l10n.tutorialInfoBubbleTitle, 'Detalles del Viaje');
      expect(l10n.tutorialInfoBubbleDescription,
          'Toca aquí para ver los detalles del viaje, seguir al propietario y compartir este viaje.');
      expect(l10n.tutorialCommentsBubbleTitle, 'Únete a la Conversación');
      expect(l10n.tutorialCommentsBubbleDescription,
          'Toca aquí para leer y publicar comentarios en este viaje.');
      expect(l10n.tutorialTimelineBubbleTitle, 'Ver la Línea de Tiempo');
      expect(l10n.tutorialTimelineBubbleDescription,
          'Toca aquí para ver el historial de ruta y las actualizaciones del viaje.');
      expect(l10n.tutorialSettingsBubbleTitle, 'Configuración del Viaje');
      expect(l10n.tutorialSettingsBubbleDescription,
          'Toca aquí para gestionar las actualizaciones automáticas y las opciones de ruta de este viaje.');
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
      expect(l10n.logIn, 'Se Connecter');
      expect(l10n.guest, 'Invité');
      expect(l10n.settings, 'Paramètres');
    });

    test('returns French home screen labels', () {
      expect(l10n.welcomeToWanderer, 'Bienvenue sur Wanderer');
      expect(l10n.trackAdventures,
          'Suivez vos voyages en temps réel, partagez des moments avec vos amis et débloquez des succès.');
      expect(l10n.getStarted, 'Commencer');
      expect(l10n.trackFirstAdventure, 'Suivez votre première aventure');
    });

    test('returns French tutorial labels', () {
      expect(l10n.tutorialSkip, 'Passer');
      expect(l10n.tutorialNext, 'Suivant');
      expect(l10n.tutorialMenuTitle, 'Explorez le Menu');
      expect(l10n.tutorialMenuDescription,
          'Plans de voyage, amis, réalisations et paramètres se trouvent ici.');
      expect(l10n.tutorialSearchTitle, 'Trouvez des Personnes et des Voyages');
      expect(l10n.tutorialSearchDescription,
          'Recherchez d\'autres voyageurs et des voyages publics.');
      expect(l10n.tutorialNotificationsTitle, 'Restez Informé');
      expect(l10n.tutorialNotificationsDescription,
          'Soyez notifié des commentaires, abonnements et réactions.');
      expect(l10n.tutorialNewTripTitle, 'Commencez Votre Aventure');
      expect(l10n.tutorialNewTripDescription,
          'Appuyez ici pour créer votre premier voyage et commencer le suivi en temps réel.');
    });

    test('returns French create-trip/trip-detail tutorial labels', () {
      expect(l10n.tutorialBottomNavTitle, 'Changez de Vue');
      expect(l10n.tutorialBottomNavDescription,
          'Appuyez sur Découvrir, Feed ou Mes Voyages pour explorer différentes vues.');
      expect(l10n.tutorialTripNameTitle, 'Nommez Votre Voyage');
      expect(l10n.tutorialTripNameDescription,
          'Donnez un titre à votre voyage pour que vos amis puissent le trouver.');
      expect(l10n.tutorialTripTypeTitle, 'Choisissez le Type de Voyage');
      expect(l10n.tutorialTripTypeDescription,
          'Simple pour un seul voyage, Multi-Jours pour des aventures plus longues avec des repères de jour.');
      expect(l10n.tutorialVisibilityTitle, 'Définissez Votre Visibilité');
      expect(l10n.tutorialVisibilityDescription,
          'Choisissez qui peut voir ce voyage : public, protégé ou privé.');
      expect(l10n.tutorialAutoUpdatesTitle, 'Mises à Jour Automatiques');
      expect(l10n.tutorialAutoUpdatesDescription,
          'Activez ceci pour partager votre position automatiquement à intervalle régulier, sans envoyer de mises à jour manuellement.');
      expect(l10n.tutorialCreateButtonTitle, 'Prêt à Partir');
      expect(l10n.tutorialCreateButtonDescription,
          'Appuyez ici pour créer votre voyage et commencer votre aventure.');
      expect(l10n.tutorialSendUpdateTitle, 'Partagez une Mise à Jour');
      expect(l10n.tutorialSendUpdateDescription,
          'Envoyez un message ou une photo pour informer vos abonnés en temps réel.');
      expect(l10n.tutorialTripStatusTitle, 'Contrôlez Votre Voyage');
      expect(l10n.tutorialTripStatusDescription,
          'Démarrez, mettez en pause ou terminez votre voyage ici.');
      expect(l10n.tutorialShareTripTitle, 'Partagez Votre Voyage');
      expect(l10n.tutorialShareTripDescription,
          'Générez un code QR ou un lien pour partager ce voyage avec d\'autres.');
      expect(l10n.tutorialInfoBubbleTitle, 'Détails du Voyage');
      expect(l10n.tutorialInfoBubbleDescription,
          'Appuyez ici pour voir les détails du voyage, suivre le propriétaire et partager ce voyage.');
      expect(l10n.tutorialCommentsBubbleTitle, 'Rejoignez la Conversation');
      expect(l10n.tutorialCommentsBubbleDescription,
          'Appuyez ici pour lire et publier des commentaires sur ce voyage.');
      expect(l10n.tutorialTimelineBubbleTitle, 'Voir la Chronologie');
      expect(l10n.tutorialTimelineBubbleDescription,
          'Appuyez ici pour voir l\'historique de l\'itinéraire et les mises à jour du voyage.');
      expect(l10n.tutorialSettingsBubbleTitle, 'Paramètres du Voyage');
      expect(l10n.tutorialSettingsBubbleDescription,
          'Appuyez ici pour gérer les mises à jour automatiques et les options d\'itinéraire de ce voyage.');
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
      expect(l10n.logIn, 'Inloggen');
      expect(l10n.guest, 'Gast');
      expect(l10n.settings, 'Instellingen');
    });

    test('returns Dutch home screen labels', () {
      expect(l10n.welcomeToWanderer, 'Welkom bij Wanderer');
      expect(l10n.trackAdventures,
          'Volg je reizen in realtime, deel momenten met vrienden en ontgrendel prestaties.');
      expect(l10n.getStarted, 'Aan de Slag');
      expect(l10n.trackFirstAdventure, 'Leg je eerste avontuur vast');
    });

    test('returns Dutch tutorial labels', () {
      expect(l10n.tutorialSkip, 'Overslaan');
      expect(l10n.tutorialNext, 'Volgende');
      expect(l10n.tutorialMenuTitle, 'Verken het Menu');
      expect(l10n.tutorialMenuDescription,
          'Reisplannen, vrienden, prestaties en instellingen vind je hier.');
      expect(l10n.tutorialSearchTitle, 'Vind Mensen & Reizen');
      expect(l10n.tutorialSearchDescription,
          'Zoek naar andere reizigers en openbare reizen.');
      expect(l10n.tutorialNotificationsTitle, 'Blijf op de Hoogte');
      expect(l10n.tutorialNotificationsDescription,
          'Ontvang meldingen over reacties, volgers en likes.');
      expect(l10n.tutorialNewTripTitle, 'Begin Je Avontuur');
      expect(l10n.tutorialNewTripDescription,
          'Tik hier om je eerste reis aan te maken en in realtime te volgen.');
    });

    test('returns Dutch create-trip/trip-detail tutorial labels', () {
      expect(l10n.tutorialBottomNavTitle, 'Wissel van Weergave');
      expect(l10n.tutorialBottomNavDescription,
          'Tik op Ontdekken, Feed of Mijn Reizen om verschillende weergaven te verkennen.');
      expect(l10n.tutorialTripNameTitle, 'Geef Je Reis een Naam');
      expect(l10n.tutorialTripNameDescription,
          'Geef je reis een titel zodat vrienden hem kunnen vinden.');
      expect(l10n.tutorialTripTypeTitle, 'Kies Je Reistype');
      expect(l10n.tutorialTripTypeDescription,
          'Eenvoudig voor één reis, Meerdaags voor langere avonturen met dagmarkeringen.');
      expect(l10n.tutorialVisibilityTitle, 'Stel Je Zichtbaarheid In');
      expect(l10n.tutorialVisibilityDescription,
          'Kies wie deze reis kan zien: openbaar, beschermd of privé.');
      expect(l10n.tutorialAutoUpdatesTitle, 'Automatische Updates');
      expect(l10n.tutorialAutoUpdatesDescription,
          'Zet dit aan om je locatie automatisch te delen met een vast interval, zonder handmatig updates te versturen.');
      expect(l10n.tutorialCreateButtonTitle, 'Klaar om te Gaan');
      expect(l10n.tutorialCreateButtonDescription,
          'Tik hier om je reis aan te maken en je avontuur te beginnen.');
      expect(l10n.tutorialSendUpdateTitle, 'Deel een Update');
      expect(l10n.tutorialSendUpdateDescription,
          'Stuur een bericht of foto om je volgers in realtime op de hoogte te houden.');
      expect(l10n.tutorialTripStatusTitle, 'Beheer Je Reis');
      expect(l10n.tutorialTripStatusDescription,
          'Start, pauzeer of beëindig je reis vanaf hier.');
      expect(l10n.tutorialShareTripTitle, 'Deel Je Reis');
      expect(l10n.tutorialShareTripDescription,
          'Genereer een QR-code of link om deze reis met anderen te delen.');
      expect(l10n.tutorialInfoBubbleTitle, 'Reisdetails');
      expect(l10n.tutorialInfoBubbleDescription,
          'Tik hier om reisdetails te bekijken, de eigenaar te volgen en deze reis te delen.');
      expect(l10n.tutorialCommentsBubbleTitle, 'Doe Mee aan het Gesprek');
      expect(l10n.tutorialCommentsBubbleDescription,
          'Tik hier om reacties op deze reis te lezen en te plaatsen.');
      expect(l10n.tutorialTimelineBubbleTitle, 'Bekijk de Tijdlijn');
      expect(l10n.tutorialTimelineBubbleDescription,
          'Tik hier om de routegeschiedenis en updates van de reis te bekijken.');
      expect(l10n.tutorialSettingsBubbleTitle, 'Reisinstellingen');
      expect(l10n.tutorialSettingsBubbleDescription,
          'Tik hier om automatische updates en routeopties voor deze reis te beheren.');
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
