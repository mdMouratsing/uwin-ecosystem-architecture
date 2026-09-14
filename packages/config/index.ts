// ============================================================================
// uWin & RetailFlow — Shared Platform Configuration
// ============================================================================

import type { ApplicationCode, CountryCode, CurrencyCode, LanguageCode, MerchantCategoryCode, ServiceCategoryCode, ServiceSubcategoryCode } from '../shared-types';

// ---------------------------------------------------------------------------
// Countries
// ---------------------------------------------------------------------------

export interface CountryConfig {
  code: CountryCode;
  name: string;
  currencyCode: CurrencyCode;
  currencySymbol: string;
  timezone: string;
  phonePrefix: string;
  dateFormat: string;
  supportedLanguages: LanguageCode[];
}

export const COUNTRIES: CountryConfig[] = [
  {
    code: 'MU',
    name: 'Mauritius',
    currencyCode: 'MUR',
    currencySymbol: 'Rs',
    timezone: 'Indian/Mauritius',
    phonePrefix: '+230',
    dateFormat: 'DD/MM/YYYY',
    supportedLanguages: ['en', 'fr'],
  },
  {
    code: 'RE',
    name: 'Réunion',
    currencyCode: 'EUR',
    currencySymbol: '€',
    timezone: 'Indian/Reunion',
    phonePrefix: '+262',
    dateFormat: 'DD/MM/YYYY',
    supportedLanguages: ['en', 'fr'],
  },
  {
    code: 'MG',
    name: 'Madagascar',
    currencyCode: 'MGA',
    currencySymbol: 'Ar',
    timezone: 'Indian/Antananarivo',
    phonePrefix: '+261',
    dateFormat: 'DD/MM/YYYY',
    supportedLanguages: ['en', 'fr'],
  },
  {
    code: 'SC',
    name: 'Seychelles',
    currencyCode: 'SCR',
    currencySymbol: 'Sr',
    timezone: 'Indian/Mahe',
    phonePrefix: '+248',
    dateFormat: 'DD/MM/YYYY',
    supportedLanguages: ['en', 'fr'],
  },
];

export const DEFAULT_COUNTRY: CountryConfig = COUNTRIES[0];

export function getCountry(code: CountryCode): CountryConfig | undefined {
  return COUNTRIES.find((c) => c.code === code);
}

// ---------------------------------------------------------------------------
// Currencies
// ---------------------------------------------------------------------------

export interface CurrencyConfig {
  code: CurrencyCode;
  name: string;
  symbol: string;
  decimalPlaces: number;
}

export const CURRENCIES: CurrencyConfig[] = [
  { code: 'MUR', name: 'Mauritian Rupee', symbol: 'Rs', decimalPlaces: 2 },
  { code: 'EUR', name: 'Euro', symbol: '€', decimalPlaces: 2 },
  { code: 'MGA', name: 'Malagasy Ariary', symbol: 'Ar', decimalPlaces: 2 },
  { code: 'SCR', name: 'Seychellois Rupee', symbol: 'Sr', decimalPlaces: 2 },
  { code: 'USD', name: 'US Dollar', symbol: '$', decimalPlaces: 2 },
];

export const DEFAULT_CURRENCY: CurrencyConfig = CURRENCIES[0];

export function getCurrency(code: CurrencyCode): CurrencyConfig | undefined {
  return CURRENCIES.find((c) => c.code === code);
}

export function formatCurrency(amount: number, currencyCode: CurrencyCode = 'MUR'): string {
  const currency = getCurrency(currencyCode) ?? DEFAULT_CURRENCY;
  const formatted = amount.toLocaleString('en-US', {
    minimumFractionDigits: currency.decimalPlaces,
    maximumFractionDigits: currency.decimalPlaces,
  });
  return `${currency.symbol} ${formatted}`;
}

// ---------------------------------------------------------------------------
// Languages
// ---------------------------------------------------------------------------

export interface LanguageConfig {
  code: LanguageCode;
  name: string;
  nativeName: string;
}

export const LANGUAGES: LanguageConfig[] = [
  { code: 'en', name: 'English', nativeName: 'English' },
  { code: 'fr', name: 'French', nativeName: 'Français' },
];

export const DEFAULT_LANGUAGE: LanguageCode = 'en';
export const SUPPORTED_LANGUAGES: LanguageCode[] = ['en', 'fr'];

// ---------------------------------------------------------------------------
// Applications / Channels Registry
// ---------------------------------------------------------------------------

export interface ApplicationConfig {
  code: ApplicationCode;
  name: string;
  description: string;
  type: 'consumer' | 'business' | 'admin';
  icon: string;
  capabilities: string[];
  sortOrder: number;
}

export const APPLICATIONS: ApplicationConfig[] = [
  {
    code: 'platform_admin',
    name: 'Platform Admin',
    description: 'IDS internal administration environment',
    type: 'admin',
    icon: 'shield',
    capabilities: ['administration', 'analytics'],
    sortOrder: 0,
  },
  {
    code: 'uwin',
    name: 'uWin',
    description: 'Consumer super-app entry point',
    type: 'consumer',
    icon: 'sparkles',
    capabilities: ['wallet', 'rewards', 'vouchers', 'campaigns', 'notifications'],
    sortOrder: 1,
  },
  {
    code: 'uwin_rewards',
    name: 'uWin Rewards',
    description: 'Loyalty and rewards experience',
    type: 'consumer',
    icon: 'award',
    capabilities: ['rewards', 'vouchers', 'campaigns', 'notifications'],
    sortOrder: 2,
  },
  {
    code: 'uwin_market',
    name: 'uWin Market',
    description: 'Marketplace for products',
    type: 'consumer',
    icon: 'shopping-bag',
    capabilities: ['shopping', 'wallet', 'rewards', 'vouchers', 'campaigns', 'notifications'],
    sortOrder: 3,
  },
  {
    code: 'uwin_services',
    name: 'uWin Services',
    description: 'Service bookings and providers',
    type: 'consumer',
    icon: 'wrench',
    capabilities: ['services', 'bookings', 'wallet', 'rewards', 'notifications'],
    sortOrder: 4,
  },
  {
    code: 'uwin_travel',
    name: 'uWin Travel',
    description: 'Travel planning and bookings',
    type: 'consumer',
    icon: 'plane',
    capabilities: ['travel', 'bookings', 'wallet', 'rewards', 'vouchers', 'notifications'],
    sortOrder: 5,
  },
  {
    code: 'uwin_resto',
    name: 'uWin Resto',
    description: 'Restaurant discovery and ordering',
    type: 'consumer',
    icon: 'utensils',
    capabilities: ['restaurant', 'bookings', 'wallet', 'rewards', 'vouchers', 'notifications'],
    sortOrder: 6,
  },
  {
    code: 'uwin_business',
    name: 'uWin Business',
    description: 'Merchant operational dashboard',
    type: 'business',
    icon: 'briefcase',
    capabilities: ['merchant_management', 'rewards', 'campaigns', 'analytics'],
    sortOrder: 7,
  },
  {
    code: 'retailflow',
    name: 'RetailFlow',
    description: 'Retail management and logistics',
    type: 'business',
    icon: 'store',
    capabilities: ['merchant_management', 'analytics', 'campaigns'],
    sortOrder: 8,
  },
  {
    code: 'retailflow_resto',
    name: 'RetailFlow Resto',
    description: 'Restaurant POS and operations',
    type: 'business',
    icon: 'chef-hat',
    capabilities: ['restaurant', 'merchant_management', 'analytics'],
    sortOrder: 9,
  },
];

export function getApplication(code: ApplicationCode): ApplicationConfig | undefined {
  return APPLICATIONS.find((a) => a.code === code);
}

// ---------------------------------------------------------------------------
// Feature Flags
// ---------------------------------------------------------------------------

export interface FeatureFlagConfig {
  key: string;
  description: string;
  isEnabled: boolean;
}

export const PLATFORM_FEATURE_FLAGS: FeatureFlagConfig[] = [
  { key: 'rewards_enabled', description: 'Enable the rewards engine across the platform', isEnabled: true },
  { key: 'wallet_enabled', description: 'Enable the universal wallet', isEnabled: true },
  { key: 'vouchers_enabled', description: 'Enable voucher issuance and redemption', isEnabled: true },
  { key: 'campaigns_enabled', description: 'Enable the campaign engine', isEnabled: true },
  { key: 'notifications_enabled', description: 'Enable the notification service', isEnabled: true },
  { key: 'merchant_directory_enabled', description: 'Enable the merchant directory', isEnabled: true },
  { key: 'analytics_enabled', description: 'Enable analytics event collection', isEnabled: true },
  { key: 'multi_country_enabled', description: 'Allow multiple countries (disable to lock to Mauritius)', isEnabled: false },
];

// ---------------------------------------------------------------------------
// Organisation Types
// ---------------------------------------------------------------------------

export const ORGANISATION_TYPES = [
  { code: 'merchant', name: 'Merchant', description: 'A retail or service merchant' },
  { code: 'retailer', name: 'Retailer', description: 'A retail business' },
  { code: 'restaurant', name: 'Restaurant', description: 'A food service establishment' },
  { code: 'distributor', name: 'Distributor', description: 'A product distributor' },
  { code: 'manufacturer', name: 'Manufacturer', description: 'A product manufacturer' },
  { code: 'hotel', name: 'Hotel', description: 'A hospitality establishment' },
  { code: 'service_provider', name: 'Service Provider', description: 'A service provider' },
  { code: 'fuel_station', name: 'Fuel Station', description: 'A fuel station operator' },
  { code: 'tourism_operator', name: 'Tourism Operator', description: 'A tourism operator' },
] as const;

// ---------------------------------------------------------------------------
// Merchant Capabilities
// ---------------------------------------------------------------------------

export const MERCHANT_CAPABILITIES = [
  'shopping',
  'restaurant',
  'services',
  'loyalty',
  'vouchers',
  'bookings',
  'offers',
  'travel',
  'payments',
  'delivery',
] as const;

// ---------------------------------------------------------------------------
// Merchant Categories
// ---------------------------------------------------------------------------

export const MERCHANT_CATEGORIES = [
  { code: 'grocery', name: 'Grocery & Supermarkets' },
  { code: 'restaurant', name: 'Restaurants & Cafés' },
  { code: 'fashion', name: 'Fashion & Apparel' },
  { code: 'electronics', name: 'Electronics' },
  { code: 'health_beauty', name: 'Health & Beauty' },
  { code: 'home_goods', name: 'Home & Furniture' },
  { code: 'fuel', name: 'Fuel & Automotive' },
  { code: 'travel_tourism', name: 'Travel & Tourism' },
  { code: 'services', name: 'Professional Services' },
  { code: 'hotels', name: 'Hotels & Accommodation' },
  { code: 'entertainment', name: 'Entertainment & Leisure' },
  { code: 'pharmacy', name: 'Pharmacy & Health' },
  { code: 'health', name: 'Health & Medical' },
] as const satisfies readonly { code: MerchantCategoryCode; name: string }[];

// ---------------------------------------------------------------------------
// Service Categories
// ---------------------------------------------------------------------------

export const SERVICE_CATEGORIES: { code: ServiceCategoryCode; name: string }[] = [
  { code: 'home', name: 'Home' },
  { code: 'repairs', name: 'Repairs' },
  { code: 'maintenance', name: 'Maintenance' },
  { code: 'beauty', name: 'Beauty' },
  { code: 'wellness', name: 'Wellness' },
  { code: 'education', name: 'Education' },
  { code: 'professional', name: 'Professional' },
  { code: 'utilities', name: 'Utilities' },
  { code: 'telecom', name: 'Telecom' },
  { code: 'appointments', name: 'Appointments' },
  { code: 'health', name: 'Health' },
];

// ---------------------------------------------------------------------------
// Service Subcategories
// ---------------------------------------------------------------------------

export const SERVICE_SUBCATEGORIES: Record<
  ServiceCategoryCode,
  { code: ServiceSubcategoryCode; name: string }[]
> = {
  home: [],
  repairs: [
    { code: 'plumbing', name: 'Plumbing' },
    { code: 'electrical', name: 'Electrical' },
  ],
  maintenance: [
    { code: 'cleaning', name: 'Cleaning' },
  ],
  beauty: [
    { code: 'facial', name: 'Facials' },
  ],
  wellness: [
    { code: 'spa', name: 'Spa' },
    { code: 'massage', name: 'Massage' },
  ],
  education: [],
  professional: [],
  utilities: [],
  telecom: [],
  appointments: [],
  health: [
    { code: 'gp', name: 'General Practitioner' },
    { code: 'dental', name: 'Dental' },
    { code: 'eye_care', name: 'Eye Care' },
    { code: 'manual_therapy', name: 'Manual Therapy' },
  ],
};

// ---------------------------------------------------------------------------
// Status Definitions (for UI display)
// ---------------------------------------------------------------------------

export interface StatusDefinition {
  value: string;
  label: string;
  variant: 'default' | 'secondary' | 'destructive' | 'outline' | 'success' | 'warning';
}

export const USER_STATUS_DEFINITIONS: StatusDefinition[] = [
  { value: 'pending', label: 'Pending', variant: 'warning' },
  { value: 'active', label: 'Active', variant: 'success' },
  { value: 'suspended', label: 'Suspended', variant: 'destructive' },
  { value: 'closed', label: 'Closed', variant: 'secondary' },
];

export const MERCHANT_STATUS_DEFINITIONS: StatusDefinition[] = [
  { value: 'draft', label: 'Draft', variant: 'secondary' },
  { value: 'pending_review', label: 'Pending Review', variant: 'warning' },
  { value: 'active', label: 'Active', variant: 'success' },
  { value: 'suspended', label: 'Suspended', variant: 'destructive' },
  { value: 'inactive', label: 'Inactive', variant: 'secondary' },
];

export const VOUCHER_STATUS_DEFINITIONS: StatusDefinition[] = [
  { value: 'issued', label: 'Issued', variant: 'default' },
  { value: 'active', label: 'Active', variant: 'success' },
  { value: 'redeemed', label: 'Redeemed', variant: 'secondary' },
  { value: 'expired', label: 'Expired', variant: 'warning' },
  { value: 'cancelled', label: 'Cancelled', variant: 'destructive' },
];

export const CAMPAIGN_STATUS_DEFINITIONS: StatusDefinition[] = [
  { value: 'draft', label: 'Draft', variant: 'secondary' },
  { value: 'scheduled', label: 'Scheduled', variant: 'default' },
  { value: 'active', label: 'Active', variant: 'success' },
  { value: 'paused', label: 'Paused', variant: 'warning' },
  { value: 'completed', label: 'Completed', variant: 'secondary' },
  { value: 'cancelled', label: 'Cancelled', variant: 'destructive' },
];

// ---------------------------------------------------------------------------
// API Conventions
// ---------------------------------------------------------------------------

export const API_VERSION = 'v1';
export const API_BASE_PATH = `/api/${API_VERSION}`;

export const API_ENDPOINTS = {
  users: `${API_BASE_PATH}/users`,
  profiles: `${API_BASE_PATH}/profiles`,
  organisations: `${API_BASE_PATH}/organisations`,
  merchants: `${API_BASE_PATH}/merchants`,
  wallets: `${API_BASE_PATH}/wallets`,
  rewards: `${API_BASE_PATH}/rewards`,
  vouchers: `${API_BASE_PATH}/vouchers`,
  campaigns: `${API_BASE_PATH}/campaigns`,
  notifications: `${API_BASE_PATH}/notifications`,
  analytics: `${API_BASE_PATH}/analytics`,
} as const;

export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;
