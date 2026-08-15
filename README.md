# Brigade des Enfants — iPhone

Application SwiftUI de conversation vocale fictive pour un usage familial accompagné. La reconnaissance vocale et la voix sont locales sur l’iPhone ; OpenAI ou Gemini génère uniquement les réponses texte.

## Compiler l'IPA avec GitHub

1. Créez un nouveau dépôt GitHub privé.
2. Importez tous les fichiers de ce dossier puis poussez-les sur la branche `main`.
3. Ouvrez **Actions → Build IPA → Run workflow**.
4. Téléchargez l'artefact **BrigadeEnfants-IPA** et décompressez-le.
5. Signez/installez `BrigadeEnfants.ipa` avec AltStore, SideStore ou un certificat Apple.

La compilation GitHub produit volontairement une IPA non signée. Aucune clé d'API ne doit être ajoutée aux fichiers GitHub.

## Première ouverture

1. Choisissez **OpenAI** ou **Gemini**.
2. Collez une clé API du fournisseur choisi. Elle est enregistrée dans le trousseau sécurisé de l'iPhone.
3. Autorisez le microphone.
4. Appuyez sur **Appeler la Brigade**.

## Télécharger une voix masculine très réaliste

Sur l’iPhone, ouvrez **Réglages → Accessibilité → Contenu énoncé → Voix → Français** et téléchargez une voix **Premium** ou **Améliorée**. Ouvrez ensuite les réglages de l’application, choisissez cette voix et utilisez **Écouter un exemple**.

La voix reste installée sur l’iPhone et sa lecture ne consomme aucun crédit OpenAI ou Gemini.

## Verrouillage du sujet

L’application vérifie localement chaque phrase avant l’appel à l’IA. Une demande sans rapport avec les enfants, leur comportement ou une petite mission éducative reçoit une réponse fixe et n’est pas envoyée à OpenAI/Gemini. Le prompt spécialisé constitue une seconde barrière et la réponse obtenue est filtrée une dernière fois avant d’être prononcée.

ChatGPT Plus et Gemini Advanced ne donnent pas automatiquement accès aux API. La consommation API est distincte.

## Sécurité de production

Le mode actuel est adapté à une application personnelle : la clé réside uniquement dans le trousseau de l'appareil. Pour distribuer l'application à d'autres personnes, utilisez un backend qui crée des jetons éphémères OpenAI/Gemini et impose authentification, quotas et limitation d'usage.

## Personnaliser

- Le comportement vocal est dans `BrigadeEnfants/SystemPrompt.swift`.
- Le nom et l'identifiant de l'application sont dans `project.yml`.
- Les modèles texte sont définis dans `TextAIService.swift`.
