// ============================================================================
// uWin & RetailFlow — Shared Platform Types
// ============================================================================
// This file defines the TypeScript contracts for every core domain object in
// the IDS digital ecosystem. All future applications import these types
// instead of redefining them.
// ============================================================================

// ---------------------------------------------------------------------------
// Base / Common
// ---------------------------------------------------------------------------

export type UUID = string;
export type ISO8601 = string;
export type CountryCode = string;
export type CurrencyCode = string;
export type LanguageCode = string;

export type EntityStatus =
  | 'draft'
  | 'pending'
  | 'pending_review'
  | 'active'
  | 'paused'
  | 'suspended'
  | 'inactive'
  | 'completed'
  | 'cancelled'
  | 'closed'
  | 'expired'
  | 'redeemed'
  | 'issued'
  | 'scheduled';

export type UserStatus = 'pending' | 'active' | 'suspended' | 'closed';

export type MerchantStatus =
  | 'draft'
  | 'pending_review'
  | 'active'
  | 'suspended'
  | 'inactive';

export type VoucherStatus =
  | 'issued'
  | 'active'
  | 'redeemed'
  | 'expired'
  | 'cancelled';

export type CampaignStatus =
  | 'draft'
  | 'scheduled'
  | 'active'
  | 'paused'
  | 'completed'
  | 'cancelled';

export type ApplicationType = 'consumer' | 'business' | 'admin';

export type ApplicationCode =
  | 'uwin'
  | 'uwin_rewards'
  | 'uwin_market'
  | 'uwin_services'
  | 'uwin_travel'
  | 'uwin_business'
  | 'uwin_resto'
  | 'retailflow'
  | 'retailflow_resto'
  | 'platform_admin';

export type PermissionScope = 'platform' | 'organisation' | 'branch' | 'own';

export type NotificationChannelType = 'in_app' | 'push' | 'email' | 'sms';

export type NotificationCategory = 'transactional' | 'marketing' | 'security' | 'loyalty';

// ---------------------------------------------------------------------------
// API Response Shapes
// ---------------------------------------------------------------------------

export interface ApiResponse<T> {
  data: T;
  meta?: ResponseMeta;
}

export interface ApiListResponse<T> {
  data: T[];
  meta: ResponseMeta;
}

export interface ResponseMeta {
  page?: number;
  pageSize?: number;
  total?: number;
  totalPages?: number;
  cursor?: string | null;
}

export interface ApiError {
  error: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
}

export interface PaginatedQuery {
  page?: number;
  pageSize?: number;
  cursor?: string;
  search?: string;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

// ---------------------------------------------------------------------------
// Country / Currency / Language
// ---------------------------------------------------------------------------

export interface Country {
  id: UUID;
  code: CountryCode;
  name: string;
  currencyCode: CurrencyCode;
  currencySymbol: string;
  timezone: string;
  phonePrefix: string;
  dateFormat: string;
  supportedLanguages: LanguageCode[];
  isActive: boolean;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface Currency {
  id: UUID;
  code: CurrencyCode;
  name: string;
  symbol: string;
  decimalPlaces: number;
  createdAt: ISO8601;
}

export interface Language {
  id: UUID;
  code: LanguageCode;
  name: string;
  nativeName: string;
  isActive: boolean;
  createdAt: ISO8601;
}

// ---------------------------------------------------------------------------
// Applications / Channels
// ---------------------------------------------------------------------------

export interface Application {
  id: UUID;
  code: ApplicationCode;
  name: string;
  description: string | null;
  type: ApplicationType;
  icon: string | null;
  status: EntityStatus;
  supportedCapabilities: string[];
  sortOrder: number;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

// ---------------------------------------------------------------------------
// Feature Flags
// ---------------------------------------------------------------------------

export interface FeatureFlag {
  id: UUID;
  key: string;
  description: string | null;
  isEnabled: boolean;
  scope: 'platform' | 'country' | 'tenant' | 'application';
  scopeRef: string | null;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

// ---------------------------------------------------------------------------
// Identity / Users
// ---------------------------------------------------------------------------

export interface User {
  id: UUID;
  email: string;
  status: UserStatus;
  primaryOrganisationId: UUID | null;
  preferredLanguage: LanguageCode;
  countryCode: CountryCode;
  createdAt: ISO8601;
  updatedAt: ISO8601;
  deactivatedAt: ISO8601 | null;
}

export interface Identity {
  id: UUID;
  userId: UUID;
  identityType: 'email' | 'mobile' | 'social' | 'oauth';
  identifier: string;
  isVerified: boolean;
  isPrimary: boolean;
  verifiedAt: ISO8601 | null;
  createdAt: ISO8601;
}

export interface AuthenticationMethod {
  id: UUID;
  userId: UUID;
  method: 'password' | 'otp' | 'social' | 'passwordless';
  provider: string | null;
  isActive: boolean;
  lastUsedAt: ISO8601 | null;
  createdAt: ISO8601;
}

// ---------------------------------------------------------------------------
// Profiles
// ---------------------------------------------------------------------------

export interface Profile {
  id: UUID;
  userId: UUID;
  firstName: string | null;
  surname: string | null;
  preferredName: string | null;
  dateOfBirth: string | null;
  gender: string | null;
  primaryMobile: string | null;
  primaryEmail: string | null;
  profileImageUrl: string | null;
  preferredLanguage: LanguageCode;
  countryCode: CountryCode;
  currencyCode: CurrencyCode;
  timezone: string;
  bio: string | null;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface Address {
  id: UUID;
  profileId: UUID;
  label: string;
  line1: string;
  line2: string | null;
  city: string;
  region: string | null;
  postalCode: string | null;
  countryCode: CountryCode;
  isDefault: boolean;
  latitude: number | null;
  longitude: number | null;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface UserPreferences {
  id: UUID;
  userId: UUID;
  preferredLanguage: LanguageCode;
  preferredCurrency: CurrencyCode;
  timezone: string;
  interests: string[];
  communicationPreferences: CommunicationPreferences;
  privacyPreferences: PrivacyPreferences;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface CommunicationPreferences {
  pushEnabled: boolean;
  emailEnabled: boolean;
  smsEnabled: boolean;
  marketingEmail: boolean;
  marketingSms: boolean;
  marketingPush: boolean;
  loyaltyAlerts: boolean;
}

export interface PrivacyPreferences {
  profileVisibleToPartners: boolean;
  analyticsConsent: boolean;
  personalisationConsent: boolean;
}

// ---------------------------------------------------------------------------
// Consents
// ---------------------------------------------------------------------------

export interface Consent {
  id: UUID;
  userId: UUID;
  consentType: string;
  version: string;
  isGranted: boolean;
  grantedAt: ISO8601 | null;
  withdrawnAt: ISO8601 | null;
  createdAt: ISO8601;
}

export interface ConsentHistory {
  id: UUID;
  consentId: UUID;
  userId: UUID;
  action: 'granted' | 'withdrawn';
  previousValue: boolean;
  newValue: boolean;
  timestamp: ISO8601;
  metadata: Record<string, unknown> | null;
}

// ---------------------------------------------------------------------------
// Organisations
// ---------------------------------------------------------------------------

export interface OrganisationType {
  id: UUID;
  code: string;
  name: string;
  description: string | null;
  createdAt: ISO8601;
}

export interface Organisation {
  id: UUID;
  name: string;
  legalName: string | null;
  organisationTypeCode: string;
  registrationNumber: string | null;
  taxNumber: string | null;
  contactEmail: string | null;
  contactPhone: string | null;
  websiteUrl: string | null;
  logoUrl: string | null;
  status: EntityStatus;
  countryCode: CountryCode;
  createdAt: ISO8601;
  updatedAt: ISO8601;
  deletedAt: ISO8601 | null;
}

export interface Branch {
  id: UUID;
  organisationId: UUID;
  name: string;
  branchCode: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  addressLine1: string | null;
  addressLine2: string | null;
  city: string | null;
  region: string | null;
  postalCode: string | null;
  countryCode: CountryCode;
  latitude: number | null;
  longitude: number | null;
  status: EntityStatus;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface Department {
  id: UUID;
  organisationId: UUID;
  branchId: UUID | null;
  name: string;
  createdAt: ISO8601;
}

export interface BusinessUser {
  id: UUID;
  userId: UUID;
  organisationId: UUID;
  branchId: UUID | null;
  departmentId: UUID | null;
  jobTitle: string | null;
  status: EntityStatus;
  joinedAt: ISO8601;
  leftAt: ISO8601 | null;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface BusinessRole {
  id: UUID;
  organisationId: UUID;
  businessUserId: UUID;
  roleKey: string;
  scope: PermissionScope;
  scopeRef: UUID | null;
  assignedAt: ISO8601;
  assignedBy: UUID | null;
  createdAt: ISO8601;
}

// ---------------------------------------------------------------------------
// Merchant Directory
// ---------------------------------------------------------------------------

export interface Merchant {
  id: UUID;
  organisationId: UUID;
  merchantName: string;
  tradingName: string | null;
  description: string | null;
  logoUrl: string | null;
  coverImageUrl: string | null;
  websiteUrl: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  countryCode: CountryCode;
  status: MerchantStatus;
  loyaltyParticipation: boolean;
  voucherAcceptance: boolean;
  rating: number | null;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface MerchantCategory {
  id: UUID;
  merchantId: UUID;
  categoryCode: string;
  isPrimary: boolean;
  createdAt: ISO8601;
}

export interface MerchantLocation {
  id: UUID;
  merchantId: UUID;
  branchId: UUID | null;
  label: string;
  addressLine1: string;
  addressLine2: string | null;
  city: string;
  region: string | null;
  postalCode: string | null;
  countryCode: CountryCode;
  latitude: number | null;
  longitude: number | null;
  openingHours: Record<string, OpeningHourRange> | null;
  isPrimary: boolean;
  createdAt: ISO8601;
}

export interface OpeningHourRange {
  open: string;
  close: string;
  closed?: boolean;
}

export interface MerchantCapability {
  id: UUID;
  merchantId: UUID;
  capability: string;
  isEnabled: boolean;
  configuration: Record<string, unknown> | null;
  createdAt: ISO8601;
}

export interface MerchantChannel {
  id: UUID;
  merchantId: UUID;
  applicationCode: ApplicationCode;
  isEnabled: boolean;
  activatedAt: ISO8601 | null;
  createdAt: ISO8601;
}

// ---------------------------------------------------------------------------
// Wallet
// ---------------------------------------------------------------------------

export type WalletAssetType =
  | 'loyalty_points'
  | 'cashback'
  | 'promotional_credit'
  | 'gift_card'
  | 'prepaid_balance'
  | 'merchant_credit';

export type WalletTransactionType =
  | 'credit'
  | 'debit'
  | 'earn'
  | 'redeem'
  | 'adjustment'
  | 'expiry'
  | 'refund'
  | 'reversal'
  | 'transfer';

export type WalletTransactionStatus = 'pending' | 'completed' | 'failed' | 'reversed';

export interface Wallet {
  id: UUID;
  userId: UUID;
  label: string | null;
  status: EntityStatus;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface WalletAccount {
  id: UUID;
  walletId: UUID;
  assetType: WalletAssetType;
  currencyCode: CurrencyCode;
  balance: number;
  status: EntityStatus;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface WalletAsset {
  id: UUID;
  walletId: UUID;
  walletAccountId: UUID;
  assetType: WalletAssetType;
  reference: string | null;
  metadata: Record<string, unknown> | null;
  expiresAt: ISO8601 | null;
  status: EntityStatus;
  createdAt: ISO8601;
}

export interface WalletTransaction {
  id: UUID;
  walletId: UUID;
  walletAccountId: UUID;
  transactionType: WalletTransactionType;
  assetType: WalletAssetType;
  amount: number;
  currencyCode: CurrencyCode;
  source: string | null;
  merchantId: UUID | null;
  campaignId: UUID | null;
  applicationCode: ApplicationCode | null;
  relatedTransactionId: UUID | null;
  idempotencyKey: string | null;
  status: WalletTransactionStatus;
  metadata: Record<string, unknown> | null;
  description: string | null;
  createdAt: ISO8601;
  reversedAt: ISO8601 | null;
}

// ---------------------------------------------------------------------------
// Rewards
// ---------------------------------------------------------------------------

export interface RewardProgramme {
  id: UUID;
  name: string;
  description: string | null;
  programmeType: 'points' | 'cashback' | 'hybrid';
  status: EntityStatus;
  countryCode: CountryCode;
  startsAt: ISO8601 | null;
  endsAt: ISO8601 | null;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface RewardRule {
  id: UUID;
  programmeId: UUID;
  ruleKey: string;
  name: string;
  description: string | null;
  ruleType: 'earn' | 'redeem' | 'bonus' | 'multiplier' | 'referral' | 'challenge';
  conditions: Record<string, unknown>;
  rewardAmount: number;
  rewardAssetType: WalletAssetType;
  multiplier: number | null;
  minSpend: number | null;
  maxReward: number | null;
  merchantId: UUID | null;
  campaignId: UUID | null;
  applicationCode: ApplicationCode | null;
  isActive: boolean;
  startsAt: ISO8601 | null;
  endsAt: ISO8601 | null;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface RewardAccount {
  id: UUID;
  userId: UUID;
  programmeId: UUID;
  tierId: UUID | null;
  totalPointsEarned: number;
  totalPointsRedeemed: number;
  currentBalance: number;
  status: EntityStatus;
  enrolledAt: ISO8601;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface RewardTransaction {
  id: UUID;
  rewardAccountId: UUID;
  userId: UUID;
  transactionType: 'earn' | 'redeem' | 'adjustment' | 'expiry' | 'reversal' | 'bonus';
  amount: number;
  source: string | null;
  merchantId: UUID | null;
  campaignId: UUID | null;
  walletTransactionId: UUID | null;
  applicationCode: ApplicationCode | null;
  idempotencyKey: string | null;
  status: WalletTransactionStatus;
  metadata: Record<string, unknown> | null;
  createdAt: ISO8601;
}

export interface RewardTier {
  id: UUID;
  programmeId: UUID;
  tierName: string;
  tierLevel: number;
  minPoints: number;
  benefits: Record<string, unknown>;
  validityPeriodMonths: number | null;
  createdAt: ISO8601;
}

// ---------------------------------------------------------------------------
// Vouchers
// ---------------------------------------------------------------------------

export type VoucherType =
  | 'monetary'
  | 'percentage'
  | 'fixed_discount'
  | 'product'
  | 'service'
  | 'restaurant'
  | 'gift'
  | 'promotional';

export interface VoucherTemplate {
  id: UUID;
  name: string;
  description: string | null;
  voucherType: VoucherType;
  faceValue: number | null;
  discountPercentage: number | null;
  currencyCode: CurrencyCode;
  merchantId: UUID | null;
  campaignId: UUID | null;
  validFrom: ISO8601;
  validUntil: ISO8601;
  maxRedemptions: number | null;
  minSpend: number | null;
  categoryRestrictions: string[];
  merchantRestrictions: UUID[];
  termsAndConditions: string | null;
  imageUrl: string | null;
  status: EntityStatus;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface Voucher {
  id: UUID;
  templateId: UUID;
  code: string;
  qrCode: string | null;
  voucherType: VoucherType;
  faceValue: number | null;
  discountPercentage: number | null;
  currencyCode: CurrencyCode;
  assignedToUserId: UUID | null;
  status: VoucherStatus;
  issuedAt: ISO8601;
  redeemedAt: ISO8601 | null;
  expiredAt: ISO8601 | null;
  batchId: UUID | null;
  createdAt: ISO8601;
}

export interface VoucherBatch {
  id: UUID;
  templateId: UUID;
  batchNumber: string;
  quantity: number;
  issuedCount: number;
  redeemedCount: number;
  createdAt: ISO8601;
}

export interface VoucherRedemption {
  id: UUID;
  voucherId: UUID;
  userId: UUID;
  merchantId: UUID | null;
  transactionAmount: number | null;
  discountApplied: number | null;
  redeemedAt: ISO8601;
  applicationCode: ApplicationCode | null;
  createdAt: ISO8601;
}

export interface VoucherRule {
  id: UUID;
  templateId: UUID;
  ruleKey: string;
  conditions: Record<string, unknown>;
  isActive: boolean;
  createdAt: ISO8601;
}

// ---------------------------------------------------------------------------
// Coupons / Promo Codes
// ---------------------------------------------------------------------------

export type CouponType =
  | 'percentage'
  | 'fixed_discount'
  | 'free_shipping'
  | 'buy_one_get_one'
  | 'fixed_amount_off';

export type CouponStatus = 'issued' | 'active' | 'redeemed' | 'expired' | 'cancelled';

export interface CouponTemplate {
  id: UUID;
  name: string;
  description: string | null;
  couponType: CouponType;
  discountValue: number;
  discountPercentage: number | null;
  currencyCode: CurrencyCode;
  merchantId: UUID | null;
  campaignId: UUID | null;
  validFrom: ISO8601;
  validUntil: ISO8601;
  maxTotalRedemptions: number | null;
  maxRedemptionsPerUser: number;
  minSpend: number | null;
  maxDiscount: number | null;
  categoryRestrictions: string[];
  merchantRestrictions: UUID[];
  termsAndConditions: string | null;
  isMultiUse: boolean;
  status: EntityStatus;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface Coupon {
  id: UUID;
  templateId: UUID;
  code: string;
  couponType: CouponType;
  discountValue: number;
  discountPercentage: number | null;
  currencyCode: CurrencyCode;
  assignedToUserId: UUID | null;
  isSingleUse: boolean;
  timesUsed: number;
  status: CouponStatus;
  issuedAt: ISO8601;
  firstUsedAt: ISO8601 | null;
  lastUsedAt: ISO8601 | null;
  expiredAt: ISO8601 | null;
  createdAt: ISO8601;
}

export interface CouponRedemption {
  id: UUID;
  couponId: UUID;
  userId: UUID;
  merchantId: UUID | null;
  orderAmount: number | null;
  discountApplied: number | null;
  applicationCode: ApplicationCode | null;
  redeemedAt: ISO8601;
  createdAt: ISO8601;
}

// ---------------------------------------------------------------------------
// Campaigns
// ---------------------------------------------------------------------------

export type CampaignType =
  | 'points_bonus'
  | 'voucher'
  | 'discount'
  | 'cashback'
  | 'challenge'
  | 'referral'
  | 'targeted_promotion'
  | 'sponsored_offer';

export interface Campaign {
  id: UUID;
  name: string;
  description: string | null;
  campaignType: CampaignType;
  status: CampaignStatus;
  organisationId: UUID | null;
  merchantId: UUID | null;
  startsAt: ISO8601;
  endsAt: ISO8601;
  budget: number | null;
  currencyCode: CurrencyCode;
  applicationCode: ApplicationCode | null;
  imageUrl: string | null;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface CampaignRule {
  id: UUID;
  campaignId: UUID;
  ruleKey: string;
  conditions: Record<string, unknown>;
  rewardAmount: number | null;
  rewardAssetType: WalletAssetType | null;
  isActive: boolean;
  createdAt: ISO8601;
}

export interface CampaignTarget {
  id: UUID;
  campaignId: UUID;
  targetType: 'all_users' | 'merchant' | 'location' | 'category' | 'segment' | 'tier' | 'application';
  targetRef: string | null;
  createdAt: ISO8601;
}

export interface CampaignAsset {
  id: UUID;
  campaignId: UUID;
  assetType: 'image' | 'banner' | 'video' | 'copy';
  url: string | null;
  content: string | null;
  createdAt: ISO8601;
}

export interface CampaignRedemption {
  id: UUID;
  campaignId: UUID;
  userId: UUID;
  merchantId: UUID | null;
  rewardAmount: number | null;
  redeemedAt: ISO8601;
  applicationCode: ApplicationCode | null;
  createdAt: ISO8601;
}

export interface CampaignMetrics {
  id: UUID;
  campaignId: UUID;
  impressions: number;
  clicks: number;
  redemptions: number;
  totalRewardIssued: number;
  updatedAt: ISO8601;
}

// ---------------------------------------------------------------------------
// RBAC
// ---------------------------------------------------------------------------

export interface Role {
  id: UUID;
  roleKey: string;
  name: string;
  description: string | null;
  scope: PermissionScope;
  isSystem: boolean;
  createdAt: ISO8601;
}

export interface Permission {
  id: UUID;
  permissionKey: string;
  name: string;
  description: string | null;
  scope: PermissionScope;
  createdAt: ISO8601;
}

export interface RolePermission {
  id: UUID;
  roleId: UUID;
  permissionId: UUID;
  createdAt: ISO8601;
}

export interface UserRole {
  id: UUID;
  userId: UUID;
  roleId: UUID;
  scope: PermissionScope;
  scopeRef: UUID | null;
  assignedBy: UUID | null;
  createdAt: ISO8601;
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

export type NotificationType =
  | 'REWARD_EARNED'
  | 'REWARD_EXPIRING'
  | 'VOUCHER_RECEIVED'
  | 'VOUCHER_EXPIRING'
  | 'CAMPAIGN_AVAILABLE'
  | 'SYSTEM_MESSAGE'
  | 'ACCOUNT_SECURITY'
  | 'ORDER_CONFIRMED'
  | 'BOOKING_CONFIRMED'
  | 'RESERVATION_REMINDER'
  | 'DELIVERY_UPDATE';

export interface Notification {
  id: UUID;
  userId: UUID;
  notificationType: NotificationType;
  category: NotificationCategory;
  title: string;
  body: string;
  data: Record<string, unknown> | null;
  isRead: boolean;
  readAt: ISO8601 | null;
  applicationCode: ApplicationCode | null;
  createdAt: ISO8601;
}

export interface NotificationTemplate {
  id: UUID;
  notificationType: NotificationType;
  channel: NotificationChannelType;
  locale: LanguageCode;
  subjectTemplate: string;
  bodyTemplate: string;
  isActive: boolean;
  createdAt: ISO8601;
}

export interface NotificationPreferences {
  id: UUID;
  userId: UUID;
  pushTransactional: boolean;
  pushMarketing: boolean;
  emailTransactional: boolean;
  emailMarketing: boolean;
  smsTransactional: boolean;
  smsMarketing: boolean;
  loyaltyAlerts: boolean;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface NotificationDelivery {
  id: UUID;
  notificationId: UUID;
  channel: NotificationChannelType;
  status: 'pending' | 'sent' | 'delivered' | 'failed';
  providerReference: string | null;
  sentAt: ISO8601 | null;
  deliveredAt: ISO8601 | null;
  error: string | null;
  createdAt: ISO8601;
}

// ---------------------------------------------------------------------------
// Analytics
// ---------------------------------------------------------------------------

export interface AnalyticsEvent {
  id: UUID;
  eventId: string;
  eventName: string;
  userId: UUID | null;
  anonymousId: string | null;
  sessionId: string | null;
  organisationId: UUID | null;
  merchantId: UUID | null;
  applicationCode: ApplicationCode | null;
  screenName: string | null;
  timestamp: ISO8601;
  countryCode: CountryCode | null;
  properties: Record<string, unknown>;
}

// ---------------------------------------------------------------------------
// Audit
// ---------------------------------------------------------------------------

export interface AuditLog {
  id: UUID;
  actorId: UUID | null;
  action: string;
  entityType: string;
  entityId: UUID | null;
  previousValue: Record<string, unknown> | null;
  newValue: Record<string, unknown> | null;
  metadata: Record<string, unknown> | null;
  ipAddress: string | null;
  userAgent: string | null;
  timestamp: ISO8601;
}

// ---------------------------------------------------------------------------
// Integrations / Webhooks
// ---------------------------------------------------------------------------

export interface IntegrationConfig {
  id: UUID;
  integrationKey: string;
  name: string;
  provider: string | null;
  configuration: Record<string, unknown> | null;
  isActive: boolean;
  createdAt: ISO8601;
  updatedAt: ISO8601;
}

export interface WebhookSubscription {
  id: UUID;
  eventType: string;
  targetUrl: string;
  isActive: boolean;
  secret: string | null;
  createdAt: ISO8601;
}

// ---------------------------------------------------------------------------
// Platform Events (lightweight event bus abstraction)
// ---------------------------------------------------------------------------

export interface PlatformEvent<T = Record<string, unknown>> {
  eventId: string;
  eventType: string;
  timestamp: ISO8601;
  payload: T;
}

export type PlatformEventType =
  | 'user.created'
  | 'profile.updated'
  | 'merchant.created'
  | 'wallet.transaction.created'
  | 'reward.earned'
  | 'reward.redeemed'
  | 'voucher.issued'
  | 'voucher.redeemed'
  | 'campaign.activated'
  | 'notification.requested';

// ---------------------------------------------------------------------------
// Cross-Service Transaction Result
// ---------------------------------------------------------------------------

export interface CrossServiceTransactionResult {
  walletTransaction: WalletTransaction;
  rewardTransaction: RewardTransaction | null;
  analyticsEventId: UUID;
  notificationId: UUID | null;
  auditLogId: UUID;
  pointsEarned: number;
  newRewardBalance: number;
}
