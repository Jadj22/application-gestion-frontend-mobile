# Designs Stitch — DODOME

Maquettes générées via [Google Stitch](https://stitch.withgoogle.com) (MCP).

## Projet Stitch

- **Nom** : OpsTrack ERP (dashboard régénéré le 18/08/2026)
- **ID** : `9235544124643662404`
- **Écran dashboard** : `92bd859f2c3848cabd8931c4821d94ff` — « DODOME - Accueil Dashboard »
- **Design system** : L'Équilibre Éditorial / DODOME Premium B2B (`#6C8EA4`, `#102A3A`, `#FAF9FB`)

## Écrans disponibles

| Dossier | Titre Stitch | Usage Flutter |
|---------|--------------|---------------|
| `Connexion_DODOME/` | Connexion - DODOME | `login_page.dart` |
| `Dashboard_DODOME/` | Tableau de bord - DODOME | `home_screen.dart` |
| `Fiche_Article_-_Chaise_Napoléon_677aca6a/` | Fiche Article | `item_detail_screen.dart` |

Chaque dossier contient :

- `design.html` — code HTML/Tailwind exporté par Stitch
- `screenshot.png` — capture visuelle
- `meta.json` — métadonnées (couleurs, tokens, IDs)

## Palette (design system)

| Token | Hex |
|-------|-----|
| Primary | `#6C8EA4` |
| Secondary / Navy | `#102A3A` |
| Background | `#FAF9FB` |
| On Surface | `#1A1C1D` |

## Régénérer un écran

Depuis Cursor (après redémarrage pour activer le MCP Stitch) :

> « Génère l'écran de connexion DODOME avec Stitch »

Ou via l'API MCP : `generate_screen_from_text` sur le projet ci-dessus.
