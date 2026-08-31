import 'package:flutter/material.dart';

/// Templates de procedures predefinies pour faciliter la creation.
/// Chaque template contient un nom, une description, une icone et des etapes.
class ProcedureTemplate {
  final String id;
  final String nom;
  final String description;
  final IconData icon;
  final Color color;
  final List<StepTemplate> steps;

  const ProcedureTemplate({
    required this.id,
    required this.nom,
    required this.description,
    required this.icon,
    required this.color,
    required this.steps,
  });
}

class StepTemplate {
  final String nom;
  final String type; // OPERATION ou CONTROLE
  final bool obligatoire;
  final String description;

  const StepTemplate({
    required this.nom,
    this.type = 'OPERATION',
    this.obligatoire = true,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'type': type,
        'obligatoire': obligatoire,
        'description': description,
      };
}

/// Catalogue des templates disponibles.
class ProcedureTemplates {
  ProcedureTemplates._();

  static const Color _bleu = Color(0xFF2196F3);
  static const Color _vert = Color(0xFF4CAF50);
  static const Color _orange = Color(0xFFFF9800);
  static const Color _violet = Color(0xFF9C27B0);
  static const Color _rouge = Color(0xFFF44336);
  static const Color _cyan = Color(0xFF00BCD4);

  /// Templates predefinies
  static const List<ProcedureTemplate> all = [
    // Nettoyage standard
    ProcedureTemplate(
      id: 'nettoyage_standard',
      nom: 'Nettoyage standard',
      description: 'Procedure de nettoyage complete pour articles textiles',
      icon: Icons.local_laundry_service_outlined,
      color: _bleu,
      steps: [
        StepTemplate(nom: 'Tri et verification', description: 'Verifier l\'etat et trier par couleur/matiere'),
        StepTemplate(nom: 'Pre-traitement', description: 'Traiter les taches si necessaire'),
        StepTemplate(nom: 'Lavage', description: 'Lavage selon les instructions'),
        StepTemplate(nom: 'Sechage', description: 'Sechage adapte au textile'),
        StepTemplate(nom: 'Controle qualite', type: 'CONTROLE', description: 'Verifier proprete et etat'),
      ],
    ),

    // Repassage
    ProcedureTemplate(
      id: 'repassage',
      nom: 'Repassage',
      description: 'Procedure de repassage et mise en forme',
      icon: Icons.iron_outlined,
      color: _orange,
      steps: [
        StepTemplate(nom: 'Preparation', description: 'Humidifier si necessaire'),
        StepTemplate(nom: 'Repassage', description: 'Repasser selon le type de tissu'),
        StepTemplate(nom: 'Pliage/Cintrage', description: 'Plier ou mettre sur cintre'),
        StepTemplate(nom: 'Controle aspect', type: 'CONTROLE', description: 'Verifier l\'absence de plis'),
      ],
    ),

    // Controle qualite
    ProcedureTemplate(
      id: 'controle_qualite',
      nom: 'Controle qualite',
      description: 'Verification complete avant mise en stock',
      icon: Icons.verified_outlined,
      color: _vert,
      steps: [
        StepTemplate(nom: 'Inspection visuelle', type: 'CONTROLE', description: 'Verifier l\'etat general'),
        StepTemplate(nom: 'Verification proprete', type: 'CONTROLE', description: 'Confirmer absence de taches'),
        StepTemplate(nom: 'Controle dimensions', type: 'CONTROLE', description: 'Verifier taille/forme'),
        StepTemplate(nom: 'Validation finale', type: 'CONTROLE', description: 'Approuver pour mise en stock'),
      ],
    ),

    // Reparation
    ProcedureTemplate(
      id: 'reparation',
      nom: 'Reparation',
      description: 'Procedure de reparation et remise en etat',
      icon: Icons.build_outlined,
      color: _rouge,
      steps: [
        StepTemplate(nom: 'Diagnostic', description: 'Identifier les reparations necessaires'),
        StepTemplate(nom: 'Reparation couture', description: 'Reparer coutures/boutons'),
        StepTemplate(nom: 'Reparation tissu', description: 'Repriser/rapicer si necessaire'),
        StepTemplate(nom: 'Test solidite', type: 'CONTROLE', description: 'Verifier la qualite des reparations'),
        StepTemplate(nom: 'Nettoyage final', description: 'Nettoyer apres reparation'),
      ],
    ),

    // Preparation location
    ProcedureTemplate(
      id: 'preparation_location',
      nom: 'Preparation location',
      description: 'Mise en condition avant remise au client',
      icon: Icons.inventory_2_outlined,
      color: _violet,
      steps: [
        StepTemplate(nom: 'Verification disponibilite', type: 'CONTROLE', description: 'Confirmer l\'article en stock'),
        StepTemplate(nom: 'Inspection etat', type: 'CONTROLE', description: 'Verifier l\'etat avant remise'),
        StepTemplate(nom: 'Nettoyage rapide', description: 'Depoussierag/rafraichissement'),
        StepTemplate(nom: 'Emballage', description: 'Emballer pour transport'),
        StepTemplate(nom: 'Etiquetage', description: 'Ajouter etiquette client/reservation'),
      ],
    ),

    // Retour client
    ProcedureTemplate(
      id: 'retour_client',
      nom: 'Retour client',
      description: 'Traitement des articles retournes',
      icon: Icons.assignment_return_outlined,
      color: _cyan,
      steps: [
        StepTemplate(nom: 'Reception', description: 'Recevoir et identifier l\'article'),
        StepTemplate(nom: 'Inspection dommages', type: 'CONTROLE', description: 'Verifier presence de dommages'),
        StepTemplate(nom: 'Photo etat', description: 'Photographier l\'etat au retour'),
        StepTemplate(nom: 'Nettoyage complet', description: 'Nettoyer avant remise en stock'),
        StepTemplate(nom: 'Remise en stock', description: 'Ranger a son emplacement'),
      ],
    ),
  ];

  /// Suggestions de noms d'etapes courants pour l'auto-completion.
  static const List<String> stepSuggestions = [
    // Operations courantes
    'Tri et verification',
    'Pre-traitement',
    'Lavage',
    'Lavage delicat',
    'Lavage a sec',
    'Rincage',
    'Essorage',
    'Sechage',
    'Sechage a plat',
    'Repassage',
    'Defroissage vapeur',
    'Pliage',
    'Cintrage',
    'Emballage',
    'Etiquetage',
    'Nettoyage rapide',
    'Detachage',
    'Desinfection',
    'Parfumage',
    'Preparation',
    'Reparation couture',
    'Remplacement bouton',
    'Reprisage',
    'Ajustement',
    'Photo etat',
    'Reception',
    'Expedition',
    'Remise en stock',
    'Rangement',
    // Controles
    'Controle qualite',
    'Controle aspect',
    'Controle proprete',
    'Controle dimensions',
    'Inspection visuelle',
    'Inspection dommages',
    'Verification disponibilite',
    'Test solidite',
    'Validation finale',
  ];

  /// Recherche de suggestions basee sur la saisie.
  static List<String> searchSuggestions(String query) {
    if (query.isEmpty) return stepSuggestions.take(10).toList();
    final lower = query.toLowerCase();
    return stepSuggestions
        .where((s) => s.toLowerCase().contains(lower))
        .take(8)
        .toList();
  }
}
