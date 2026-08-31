import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Facture (Proforma / Définitive) — `InvoiceSerializer` côté backend (V4).
class InvoiceModel {
  final String id;
  final String numero;
  final String type; // PROFORMA, DEFINITIVE, AVOIR
  final String typeDisplay;
  final String statut; // BROUILLON, PROFORMA, DEFINITIVE, PAYEE, ANNULEE
  final String statutDisplay;
  final String reservationId;
  final String itemNom;
  final String clientNom;
  final String clientEmail;
  final String clientTelephone;
  final String clientAdresse;
  final List<InvoiceLineModel> lignes;
  final num sousTotal;
  final num tvaTaux;
  final num tvaMontant;
  final num totalTtc;
  final String? pdfUrl;
  final DateTime genereeLe;
  final DateTime? envoyeeLe;
  final DateTime? payeeLe;

  const InvoiceModel({
    required this.id,
    required this.numero,
    required this.type,
    required this.typeDisplay,
    required this.statut,
    required this.statutDisplay,
    required this.reservationId,
    required this.itemNom,
    required this.clientNom,
    required this.clientEmail,
    required this.clientTelephone,
    required this.clientAdresse,
    required this.lignes,
    required this.sousTotal,
    required this.tvaTaux,
    required this.tvaMontant,
    required this.totalTtc,
    this.pdfUrl,
    required this.genereeLe,
    this.envoyeeLe,
    this.payeeLe,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final lignesJson = (json['lignes'] as List?) ?? [];
    return InvoiceModel(
      id: json['id'] as String,
      numero: json['numero'] as String,
      type: json['type'] as String,
      typeDisplay: (json['type_display'] as String?) ?? '',
      statut: json['statut'] as String,
      statutDisplay: (json['statut_display'] as String?) ?? '',
      reservationId: json['reservation_id'] as String,
      itemNom: (json['item_nom'] as String?) ?? '',
      clientNom: (json['client_nom'] as String?) ?? '',
      clientEmail: (json['client_email'] as String?) ?? '',
      clientTelephone: (json['client_telephone'] as String?) ?? '',
      clientAdresse: (json['client_adresse'] as String?) ?? '',
      lignes: lignesJson.map((e) => InvoiceLineModel.fromJson(e as Map<String, dynamic>)).toList(),
      sousTotal: (json['sous_total'] as num?) ?? 0,
      tvaTaux: (json['tva_taux'] as num?) ?? 0,
      tvaMontant: (json['tva_montant'] as num?) ?? 0,
      totalTtc: (json['total_ttc'] as num?) ?? 0,
      pdfUrl: json['pdf_url'] as String?,
      genereeLe: DateTime.tryParse((json['generee_le'] as String?) ?? '') ?? DateTime.now(),
      envoyeeLe: json['envoyee_le'] != null ? DateTime.tryParse(json['envoyee_le'] as String) : null,
      payeeLe: json['payee_le'] != null ? DateTime.tryParse(json['payee_le'] as String) : null,
    );
  }

  String get montantTotalFormate {
    return '${NumberFormat('#,##0', 'fr_FR').format(totalTtc)} FCFA';
  }

  String get sousTotalFormate {
    return '${NumberFormat('#,##0', 'fr_FR').format(sousTotal)} FCFA';
  }

  String get tvaMontantFormate {
    return '${NumberFormat('#,##0', 'fr_FR').format(tvaMontant)} FCFA';
  }

  bool get estProforma => type == 'PROFORMA';
  bool get estDefinitive => type == 'DEFINITIVE';
  bool get estPayee => statut == 'PAYEE';
  bool get estAnnulee => statut == 'ANNULEE';

  Color get statutColor {
    switch (statut) {
      case 'BROUILLON':
        return Colors.grey;
      case 'PROFORMA':
        return Colors.blue;
      case 'DEFINITIVE':
        return Colors.indigo;
      case 'PAYEE':
        return Colors.green;
      case 'ANNULEE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get dateGenereeFormatee {
    return DateFormat('dd/MM/yyyy HH:mm').format(genereeLe);
  }
}

/// Ligne de facture
class InvoiceLineModel {
  final String description;
  final int quantite;
  final num prixUnitaire;
  final num total;

  const InvoiceLineModel({
    required this.description,
    required this.quantite,
    required this.prixUnitaire,
    required this.total,
  });

  factory InvoiceLineModel.fromJson(Map<String, dynamic> json) {
    return InvoiceLineModel(
      description: (json['description'] as String?) ?? '',
      quantite: (json['quantite'] as num?)?.toInt() ?? 1,
      prixUnitaire: (json['prix_unitaire'] as num?) ?? 0,
      total: (json['total'] as num?) ?? 0,
    );
  }

  String get totalFormate => '${NumberFormat('#,##0', 'fr_FR').format(total)} FCFA';
  String get prixUnitaireFormate => '${NumberFormat('#,##0', 'fr_FR').format(prixUnitaire)} FCFA';
}