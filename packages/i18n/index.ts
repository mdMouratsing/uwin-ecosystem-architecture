// ============================================================================
// uWin & RetailFlow — Internationalisation Foundation
// ============================================================================
// Supports English (en) and French (fr). Mauritian Creole (mfe) can be added
// later by adding a new locale file and registering it here.
// ============================================================================

import type { LanguageCode } from '../shared-types';

export type TranslationKey = keyof typeof translations.en;

export const translations = {
  en: {
    // Common
    'common.loading': 'Loading…',
    'common.save': 'Save',
    'common.cancel': 'Cancel',
    'common.delete': 'Delete',
    'common.edit': 'Edit',
    'common.search': 'Search',
    'common.actions': 'Actions',
    'common.viewAll': 'View all',
    'common.back': 'Back',
    'common.confirm': 'Confirm',
    'common.close': 'Close',
    'common.retry': 'Retry',
    'common.error': 'Something went wrong',
    'common.noData': 'No data available',
    'common.noResults': 'No results found',
    'common.page': 'Page',
    'common.of': 'of',
    'common.total': 'Total',

    // Navigation
    'nav.dashboard': 'Dashboard',
    'nav.users': 'Users',
    'nav.organisations': 'Organisations',
    'nav.merchants': 'Merchants',
    'nav.rewards': 'Rewards',
    'nav.wallet': 'Wallet',
    'nav.campaigns': 'Campaigns',
    'nav.notifications': 'Notifications',
    'nav.rolesPermissions': 'Roles & Permissions',
    'nav.architectureDemo': 'Architecture Demo',
    'nav.architectureContract': 'Architecture Contract',

    // Auth
    'auth.signIn': 'Sign in',
    'auth.signUp': 'Sign up',
    'auth.signOut': 'Sign out',
    'auth.email': 'Email',
    'auth.password': 'Password',
    'auth.signInTitle': 'Platform Admin Sign In',
    'auth.signInDescription': 'Sign in to the IDS platform administration environment',
    'auth.invalidCredentials': 'Invalid email or password',
    'auth.authenticated': 'Authenticated',
    'auth.unauthenticated': 'Not signed in',

    // Dashboard
    'dashboard.title': 'Platform Dashboard',
    'dashboard.subtitle': 'Ecosystem overview across all shared services',
    'dashboard.totalUsers': 'Total Users',
    'dashboard.organisations': 'Organisations',
    'dashboard.merchants': 'Merchants',
    'dashboard.walletTransactions': 'Wallet Transactions',
    'dashboard.rewardTransactions': 'Reward Transactions',
    'dashboard.activeCampaigns': 'Active Campaigns',
    'dashboard.notifications': 'Notifications',

    // Demo
    'demo.consumer.title': 'Consumer Demo — Aisha Raman',
    'demo.merchant.title': 'Merchant Demo — Lagoon Market Ltd',
    'demo.crossService.title': 'Cross-Service Transaction Demo',
    'demo.crossService.description': 'Simulate a transaction at Lagoon Market to see the shared services work end-to-end: wallet ledger, reward rule evaluation, analytics event, notification, and audit trail.',
    'demo.crossService.trigger': 'Run Transaction',
    'demo.crossService.amount': 'Amount (Rs)',
    'demo.crossService.running': 'Processing transaction…',
    'demo.crossService.success': 'Transaction completed successfully',
    'demo.crossService.pointsEarned': 'Points earned',
    'demo.crossService.newBalance': 'New reward balance',

    // Entity labels
    'entity.uwinId': 'uWin ID',
    'entity.profile': 'Profile',
    'entity.wallet': 'Wallet',
    'entity.rewardBalance': 'Reward Balance',
    'entity.rewardTier': 'Tier',
    'entity.vouchers': 'Vouchers',
    'entity.notificationPreferences': 'Notification Preferences',
    'entity.organisation': 'Organisation',
    'entity.merchantProfile': 'Merchant Profile',
    'entity.branch': 'Branch',
    'entity.loyaltyParticipation': 'Loyalty Participation',
    'entity.staffUser': 'Staff User',

    // Status
    'status.active': 'Active',
    'status.inactive': 'Inactive',
    'status.pending': 'Pending',
    'status.suspended': 'Suspended',

    // Brand
    'brand.ids': 'IDS Platform',
    'brand.idsFull': 'Intelligent Digitalisation Solutions',
    'brand.uwin': 'uWin',
    'brand.retailflow': 'RetailFlow',
    'brand.platformAdmin': 'Platform Admin',
  },

  fr: {
    // Common
    'common.loading': 'Chargement…',
    'common.save': 'Enregistrer',
    'common.cancel': 'Annuler',
    'common.delete': 'Supprimer',
    'common.edit': 'Modifier',
    'common.search': 'Rechercher',
    'common.actions': 'Actions',
    'common.viewAll': 'Voir tout',
    'common.back': 'Retour',
    'common.confirm': 'Confirmer',
    'common.close': 'Fermer',
    'common.retry': 'Réessayer',
    'common.error': 'Une erreur est survenue',
    'common.noData': 'Aucune donnée disponible',
    'common.noResults': 'Aucun résultat trouvé',
    'common.page': 'Page',
    'common.of': 'sur',
    'common.total': 'Total',

    // Navigation
    'nav.dashboard': 'Tableau de bord',
    'nav.users': 'Utilisateurs',
    'nav.organisations': 'Organisations',
    'nav.merchants': 'Commerçants',
    'nav.rewards': 'Récompenses',
    'nav.wallet': 'Portefeuille',
    'nav.campaigns': 'Campagnes',
    'nav.notifications': 'Notifications',
    'nav.rolesPermissions': 'Rôles et Permissions',
    'nav.architectureDemo': 'Démo Architecture',
    'nav.architectureContract': 'Contrat d\'Architecture',

    // Auth
    'auth.signIn': 'Se connecter',
    'auth.signUp': 'S\'inscrire',
    'auth.signOut': 'Se déconnecter',
    'auth.email': 'E-mail',
    'auth.password': 'Mot de passe',
    'auth.signInTitle': 'Connexion Admin Plateforme',
    'auth.signInDescription': 'Connectez-vous à l\'environnement d\'administration IDS',
    'auth.invalidCredentials': 'E-mail ou mot de passe invalide',
    'auth.authenticated': 'Authentifié',
    'auth.unauthenticated': 'Non connecté',

    // Dashboard
    'dashboard.title': 'Tableau de bord Plateforme',
    'dashboard.subtitle': 'Vue d\'ensemble de l\'écosystème across tous les services partagés',
    'dashboard.totalUsers': 'Utilisateurs totaux',
    'dashboard.organisations': 'Organisations',
    'dashboard.merchants': 'Commerçants',
    'dashboard.walletTransactions': 'Transactions Portefeuille',
    'dashboard.rewardTransactions': 'Transactions Récompenses',
    'dashboard.activeCampaigns': 'Campagnes actives',
    'dashboard.notifications': 'Notifications',

    // Demo
    'demo.consumer.title': 'Démo Consommateur — Aisha Raman',
    'demo.merchant.title': 'Démo Commerçant — Lagoon Market Ltd',
    'demo.crossService.title': 'Démo Transaction Inter-Services',
    'demo.crossService.description': 'Simulez une transaction chez Lagoon Market pour voir les services partagés fonctionner: grand livre portefeuille, évaluation des règles de récompense, événement analytique, notification et piste d\'audit.',
    'demo.crossService.trigger': 'Exécuter la transaction',
    'demo.crossService.amount': 'Montant (Rs)',
    'demo.crossService.running': 'Traitement de la transaction…',
    'demo.crossService.success': 'Transaction réussie',
    'demo.crossService.pointsEarned': 'Points gagnés',
    'demo.crossService.newBalance': 'Nouveau solde de récompenses',

    // Entity labels
    'entity.uwinId': 'Identifiant uWin',
    'entity.profile': 'Profil',
    'entity.wallet': 'Portefeuille',
    'entity.rewardBalance': 'Solde Récompenses',
    'entity.rewardTier': 'Niveau',
    'entity.vouchers': 'Bons',
    'entity.notificationPreferences': 'Préférences de notification',
    'entity.organisation': 'Organisation',
    'entity.merchantProfile': 'Profil Commerçant',
    'entity.branch': 'Succursale',
    'entity.loyaltyParticipation': 'Participation Fidélité',
    'entity.staffUser': 'Utilisateur Personnel',

    // Status
    'status.active': 'Actif',
    'status.inactive': 'Inactif',
    'status.pending': 'En attente',
    'status.suspended': 'Suspendu',

    // Brand
    'brand.ids': 'Plateforme IDS',
    'brand.idsFull': 'Intelligent Digitalisation Solutions',
    'brand.uwin': 'uWin',
    'brand.retailflow': 'RetailFlow',
    'brand.platformAdmin': 'Admin Plateforme',
  },
} as const;

export type Translations = typeof translations;
type LocaleKey = keyof Translations;

export function translate(key: TranslationKey, locale: LanguageCode = 'en'): string {
  const localeKey = (locale in translations ? locale : 'en') as LocaleKey;
  const localeTranslations = translations[localeKey];
  return localeTranslations[key] ?? translations.en[key] ?? key;
}

export function isSupportedLocale(code: string): code is LanguageCode {
  return code === 'en' || code === 'fr';
}
