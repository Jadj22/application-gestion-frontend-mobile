import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/offline/entity_registry.dart';
import '../../../core/offline/offline_repository.dart';
import 'models/member.dart';
import 'models/role.dart';

/// Équipe et rôles du business.
///
/// Lecture hors ligne, écriture en ligne uniquement — un choix de sécurité
/// délibéré :
///
/// * inviter un membre envoie un e-mail et crée un compte : rien à simuler ;
/// * changer un rôle modifie des permissions, et le backend reste l'autorité
///   (RM-19). Appliquer un changement de droits en local, même temporairement,
///   ouvrirait une fenêtre où l'application croit à des permissions que le
///   serveur n'a jamais accordées.
///
/// Les rôles restent en revanche **lus** localement : sans eux, l'interface ne
/// saurait plus quoi afficher à l'ouverture hors ligne.
class MembersRepository {
  final ApiClient _api;
  final OfflineRepository _offline;

  MembersRepository(this._api, this._offline);

  /// Rôles du business, servis depuis la copie locale hors ligne.
  Future<List<Role>> roles(String businessId, {bool refresh = false}) async {
    final rows = await _offline.readCollection(
      EntityRegistry.role,
      businessId,
      refresh: refresh,
    );
    return rows.map(Role.fromJson).toList();
  }

  Future<List<Member>> members(String businessId,
      {bool refresh = false}) async {
    final rows = await _offline.readCollection(
      EntityRegistry.member,
      businessId,
      refresh: refresh,
    );
    return rows.map(Member.fromJson).toList();
  }

  /// Invite un collaborateur (member.invite). **Exige le réseau.**
  Future<Member> invite(
    String businessId, {
    required String email,
    String? roleId,
    String firstName = '',
    String lastName = '',
  }) async {
    _requireNetwork('Inviter un membre');
    final data = await _api.post(
      ApiEndpoints.businessMembers(businessId),
      body: {
        'email': email,
        'role_id': ?roleId,
        if (firstName.isNotEmpty) 'first_name': firstName,
        if (lastName.isNotEmpty) 'last_name': lastName,
      },
    ) as Map<String, dynamic>;
    await _offline.store.putFromServer(
      EntityRegistry.member.type,
      data,
      businessId: businessId,
    );
    return Member.fromJson(data);
  }

  /// Change le rôle et/ou le statut (member.role_update). **Exige le réseau.**
  Future<Member> update(
    String businessId,
    String memberId, {
    String? roleId,
    String? statut,
  }) async {
    _requireNetwork('Modifier un membre');
    final data = await _api.patch(
      ApiEndpoints.businessMember(businessId, memberId),
      body: {
        'role_id': ?roleId,
        'statut': ?statut,
      },
    ) as Map<String, dynamic>;
    await _offline.store.putFromServer(
      EntityRegistry.member.type,
      data,
      businessId: businessId,
    );
    return Member.fromJson(data);
  }

  /// Retire un membre (member.remove). **Exige le réseau.**
  Future<void> remove(String businessId, String memberId) async {
    _requireNetwork('Retirer un membre');
    await _api.delete(ApiEndpoints.businessMember(businessId, memberId));
    await _offline.store.purge(EntityRegistry.member.type, memberId);
  }

  void _requireNetwork(String action) {
    if (_offline.connectivity.isOffline) {
      throw OfflineUnsupportedException(
        '$action nécessite une connexion Internet : cette opération touche '
        'aux droits d\'accès et au compte de la personne concernée.',
      );
    }
  }
}
