/// Contrat d'API du backend Django REST (Sprint 1).
class ApiEndpoints {
  ApiEndpoints._();

  /// Sonde de disponibilité du backend (Offline-First).
  ///
  /// Endpoint public et minimal : être associé à un Wi-Fi ne prouve pas que
  /// l'API répond (portail captif, VPN, serveur éteint). C'est cette route
  /// qui décide de l'état ONLINE, pas l'interface réseau du téléphone.
  static const String health = '/health/';

  // Auth (S 1-02 / S 1-04)
  static const String register = '/auth/register/';
  static const String login = '/auth/login/';
  static const String google = '/auth/google/';
  static const String refresh = '/auth/refresh/';
  static const String me = '/auth/me/';

  // Devices / Push Notifications
  static const String devices = '/devices/';
  static String device(String deviceId) => '/devices/$deviceId/';

  // Invitations (Sprint 10 lien, Sprint 11 code)
  static const String invitationAccept = '/invitations/accept/';
  static const String invitationValidate = '/invitations/validate/';
  static String invitationPreview(String token) => '/invitations/$token/';

  // IA : description automatique d'une photo (Sprint 10)
  static const String aiImageDescription = '/ai/image-description/';

  /// IA : generation d'une fiche article a partir d'un texte, sans photo.
  ///
  /// Pendant textuel de [aiImageDescription] : la photo n'est plus la seule
  /// porte d'entree vers l'IA, et n'en est plus le declencheur.
  static const String aiItemDescription = '/ai/item-description/';

  // Businesses (US-01) — tunnel d'onboarding
  static const String businessTypes = '/business-types/';
  static const String businesses = '/businesses/';

  // Rôles & permissions (US-04, RM-19)
  static const String permissions = '/permissions/';
  static String businessRoles(String businessId) =>
      '/businesses/$businessId/roles/';

  // Membres (US-02, US-03)
  static String businessMembers(String businessId) =>
      '/businesses/$businessId/members/';
  static String businessMember(String businessId, String memberId) =>
      '/businesses/$businessId/members/$memberId/';

  // Dashboard / accueil (S 7-04)
  static String businessDashboard(String businessId) =>
      '/businesses/$businessId/dashboard/';
  static String businessStock(String businessId) =>
      '/businesses/$businessId/stock/';
  static String businessAlerts(String businessId) =>
      '/businesses/$businessId/alerts/';

  // Catalogue : catégories & articles (US-05, US-06)
  static String businessCategories(String businessId) =>
      '/businesses/$businessId/categories/';
  static String businessCategory(String businessId, String categoryId) =>
      '/businesses/$businessId/categories/$categoryId/';
  static String businessItems(String businessId) =>
      '/businesses/$businessId/items/';
  static String businessItem(String businessId, String itemId) =>
      '/businesses/$businessId/items/$itemId/';
  static String businessItemStock(String businessId, String itemId) =>
      '/businesses/$businessId/items/$itemId/stock/';
  static String businessItemStockHistory(String businessId, String itemId) =>
      '/businesses/$businessId/items/$itemId/stock/history/';
  static String businessItemPhotos(String businessId, String itemId) =>
      '/businesses/$businessId/items/$itemId/photos/';

  /// Proposition de reference libre pour un article (calcul pur, sans IA).
  static String businessItemNextReference(String businessId) =>
      '/businesses/$businessId/items/next-reference/';

  // Stock : mouvements (US-08 à US-12)
  static String businessStockMovements(String businessId) =>
      '/businesses/$businessId/stock/movements/';

  // Entretien (US-13 à US-17)
  static String businessMaintenanceTasks(String businessId) =>
      '/businesses/$businessId/maintenance/tasks/';
  static String businessMaintenanceTask(String businessId, String taskId) =>
      '/businesses/$businessId/maintenance/tasks/$taskId/';
  static String businessMaintenanceTaskStep(
          String businessId, String taskId, String stepId) =>
      '/businesses/$businessId/maintenance/tasks/$taskId/steps/$stepId/';
  static String businessMaintenanceTaskCloture(
          String businessId, String taskId) =>
      '/businesses/$businessId/maintenance/tasks/$taskId/cloturer/';
  static String businessProcedures(String businessId) =>
      '/businesses/$businessId/procedures/';
  static String businessProcedure(String businessId, String procedureId) =>
      '/businesses/$businessId/procedures/$procedureId/';

  // Réservations (Sprint 8, US-29 à US-31)
  static String businessReservations(String businessId) =>
      '/businesses/$businessId/reservations/';
  static String businessReservationsBulk(String businessId) =>
      '/businesses/$businessId/reservations/bulk/';
  static String businessReservation(String businessId, String reservationId) =>
      '/businesses/$businessId/reservations/$reservationId/';
  static String businessReservationAction(
          String businessId, String reservationId, String action) =>
      '/businesses/$businessId/reservations/$reservationId/$action/';

  // Sprint 3: Tâches récurrentes
  static String businessRecurringTasks(String businessId) =>
      '/businesses/$businessId/recurring-tasks/';
  static String businessRecurringTask(String businessId, String recurringId) =>
      '/businesses/$businessId/recurring-tasks/$recurringId/';

  // Sprint 3: Rappels
  static String businessReminders(String businessId) =>
      '/businesses/$businessId/reminders/';
  static String businessReminder(String businessId, String reminderId) =>
      '/businesses/$businessId/reminders/$reminderId/';

  // Sprint 4: Historique
  static String businessHistory(String businessId) =>
      '/businesses/$businessId/history/';

  // Sprint 5: Analytics
  static String businessAnalytics(String businessId) =>
      '/businesses/$businessId/analytics/';

  // Sprint 6: QR Code scanning
  static String businessItemScan(String businessId, String qrCode) =>
      '/businesses/$businessId/items/scan/$qrCode/';

  // Sprint 9: Alertes de performance
  static String businessPerformanceAlerts(String businessId) =>
      '/businesses/$businessId/performance-alerts/';
  static String businessPerformanceAlertResolve(
          String businessId, String alertId) =>
      '/businesses/$businessId/performance-alerts/$alertId/resolve/';

  // Activités & Notifications (Sprint 7)
  static String businessActivities(String businessId) =>
      '/businesses/$businessId/activities/';
  static String businessNotifications(String businessId) =>
      '/businesses/$businessId/notifications/';

  // V1: Catalogue Public (sans auth)
  static String publicCatalog(String slug) => '/public/b/$slug/items/';
  static String publicAvailability(String slug, String itemId) =>
      '/public/b/$slug/items/$itemId/availability/';

  // V2: Booking Requests Public (client externe)
  static String publicBookingRequests(String slug) =>
      '/public/b/$slug/booking-requests/';
  static String publicBookingRequestDetail(String slug, String token) =>
      '/public/b/$slug/booking-requests/$token/';
  static String publicBookingRequestCancel(String slug, String token) =>
      '/public/b/$slug/booking-requests/$token/cancel/';
  static String publicBookingRequestAcceptCounter(String slug, String token) =>
      '/public/b/$slug/booking-requests/$token/accept-counter/';
  static String publicBookingRequestRejectCounter(String slug, String token) =>
      '/public/b/$slug/booking-requests/$token/reject-counter/';

  // V2: Booking Requests Équipe
  static String businessBookingRequests(String businessId) =>
      '/businesses/$businessId/booking-requests/';
  static String businessBookingRequest(String businessId, String requestId) =>
      '/businesses/$businessId/booking-requests/$requestId/';
  static String businessBookingRequestAction(String businessId, String requestId) =>
      '/businesses/$businessId/booking-requests/$requestId/action/';

  // V4: Facturation Équipe
  static String businessInvoices(String businessId) =>
      '/businesses/$businessId/invoices/';
  static String businessInvoice(String businessId, String invoiceId) =>
      '/businesses/$businessId/invoices/$invoiceId/';
  static String businessInvoicePdf(String businessId, String invoiceId) =>
      '/businesses/$businessId/invoices/$invoiceId/pdf/';
  static String businessInvoiceMarkSent(String businessId, String invoiceId) =>
      '/businesses/$businessId/invoices/$invoiceId/mark-sent/';
  static String businessInvoiceMarkPaid(String businessId, String invoiceId) =>
      '/businesses/$businessId/invoices/$invoiceId/mark-paid/';

  // V4: Facturation Public (client)
  static String publicInvoice(String slug, String reservationId) =>
      '/public/b/$slug/invoices/$reservationId/';
  static String publicInvoicePdf(String slug, String reservationId) =>
      '/public/b/$slug/invoices/$reservationId/pdf/';
}