import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'models/business.dart';
import 'models/business_type.dart';

class BusinessRepository {
  final ApiClient _api;

  BusinessRepository(this._api);

  /// GET /business-types/ — catalogue statique (public, enveloppe paginée).
  Future<List<BusinessType>> businessTypes() async {
    final data = await _api.getList(ApiEndpoints.businessTypes, auth: false);
    return data
        .whereType<Map<String, dynamic>>()
        .map(BusinessType.fromJson)
        .toList();
  }

  /// POST /businesses/ — le backend crée rôles + règles + membership OWNER
  /// dans une transaction, puis renvoie 201 avec le business créé.
  /// Si un logo local est choisi (galerie), envoi multipart avec le fichier.
  Future<Business> create(BusinessDraft draft) async {
    final logoPath = draft.logoPath;
    if (logoPath != null && logoPath.isNotEmpty) {
      final data = await _api.uploadFile(
        ApiEndpoints.businesses,
        filePath: logoPath,
        field: 'logo',
        fields: draft.toJson().map((key, value) => MapEntry(key, '$value')),
      ) as Map<String, dynamic>;
      return Business.fromJson(data);
    }
    final data = await _api.post(
      ApiEndpoints.businesses,
      body: draft.toJson(),
    ) as Map<String, dynamic>;
    return Business.fromJson(data);
  }
}