"""
Django models for Issuer Management
Mirrors the PostgreSQL schema from shared/schema.ts
"""
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator
import uuid


class User(AbstractUser):
    """
    Custom User model with blockchain wallet integration
    """
    ROLE_CHOICES = [
        ('admin', 'Administrator'),
        ('compliance_officer', 'Compliance Officer'),
        ('custodian', 'Custodian'),
        ('regulator', 'Regulator'),
        ('issuer', 'Campaign Issuer'),
        ('investor', 'Investor'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    role = models.CharField(max_length=50, choices=ROLE_CHOICES, default='investor')
    wallet_address = models.CharField(max_length=42, unique=True, null=True, blank=True)
    kyc_level = models.CharField(
        max_length=20,
        choices=[
            ('none', 'Not Verified'),
            ('basic', 'Basic KYC'),
            ('enhanced', 'Enhanced KYC'),
            ('premium', 'Premium KYC'),
        ],
        default='none'
    )
    kyc_verified = models.BooleanField(default=False)
    kyc_verified_at = models.DateTimeField(null=True, blank=True)
    aml_risk_score = models.IntegerField(
        default=0,
        validators=[MinValueValidator(0)],
        help_text="AML risk score (0-100)"
    )
    vc_hash = models.CharField(
        max_length=255,
        null=True,
        blank=True,
        help_text="Keycloak Verifiable Credential hash"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'users'
        verbose_name = 'User'
        verbose_name_plural = 'Users'
    
    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"
    
    @property
    def is_issuer(self):
        return self.role == 'issuer'
    
    @property
    def is_investor(self):
        return self.role == 'investor'
    
    @property
    def can_create_campaigns(self):
        return self.role in ['issuer', 'admin']


class Company(models.Model):
    """
    Company model for issuers
    Dual storage: PostgreSQL + Blockchain (IssuerRegistry.sol)
    """
    SECTOR_CHOICES = [
        ('agriculture', 'Agriculture'),
        ('technology', 'Technology'),
        ('manufacturing', 'Manufacturing'),
        ('healthcare', 'Healthcare'),
        ('education', 'Education'),
        ('retail', 'Retail'),
        ('finance', 'Finance'),
        ('energy', 'Energy'),
        ('transport', 'Transport'),
        ('other', 'Other'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='companies')
    name = models.CharField(max_length=255)
    tin_number = models.CharField(max_length=50, unique=True, help_text="Tax Identification Number")
    sector = models.CharField(max_length=50, choices=SECTOR_CHOICES)
    registration_year = models.IntegerField(null=True, blank=True)
    verified = models.BooleanField(default=False)
    
    # Blockchain integration
    blockchain_address = models.CharField(max_length=42, null=True, blank=True)
    ipfs_document_hash = models.CharField(
        max_length=100,
        null=True,
        blank=True,
        help_text="IPFS hash for Information Memorandum"
    )
    registered_on_blockchain = models.BooleanField(default=False)
    blockchain_tx_hash = models.CharField(max_length=66, null=True, blank=True)
    blockchain_registered_at = models.DateTimeField(null=True, blank=True)
    
    # FIX: Exclusivity lock tracking
    has_active_campaign = models.BooleanField(
        default=False,
        help_text="True if company has an active campaign (single-campaign rule)"
    )
    active_campaign_id = models.UUIDField(
        null=True,
        blank=True,
        help_text="ID of currently active campaign"
    )
    last_campaign_year = models.IntegerField(
        null=True,
        blank=True,
        help_text="Year of last campaign (one campaign per year rule)"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'companies'
        verbose_name = 'Company'
        verbose_name_plural = 'Companies'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.name} (TIN: {self.tin_number})"
    
    @property
    def active_campaign_count(self):
        return self.campaigns.filter(status__in=['active', 'pending']).count()
    
    def can_create_campaign(self):
        """
        Check if company can create new campaign
        FIX: Implements business rules for campaign creation
        
        Rules:
        - Must be verified
        - Must be registered on blockchain
        - Cannot have active campaign (exclusivity lock)
        - One campaign per year rule
        """
        from datetime import datetime
        
        if not self.verified:
            return False, "Company not verified"
        
        if not self.registered_on_blockchain:
            return False, "Company not registered on blockchain"
        
        if self.has_active_campaign:
            return False, "Company already has an active campaign"
        
        current_year = datetime.now().year
        if self.last_campaign_year == current_year:
            return False, "Company already ran a campaign this year"
        
        return True, "OK"


class IssuerProfile(models.Model):
    """
    Extended profile for issuer users with additional business information
    """
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='issuer_profile')
    company = models.ForeignKey(Company, on_delete=models.SET_NULL, null=True, related_name='issuer_profiles')
    
    # Contact information
    phone_number = models.CharField(max_length=20, blank=True)
    business_email = models.EmailField(blank=True)
    website = models.URLField(blank=True)
    
    # Address
    street_address = models.TextField(blank=True)
    city = models.CharField(max_length=100, blank=True)
    state_province = models.CharField(max_length=100, blank=True)
    postal_code = models.CharField(max_length=20, blank=True)
    country = models.CharField(max_length=100, default='Ethiopia')
    
    # Business details
    business_description = models.TextField(blank=True)
    years_in_operation = models.IntegerField(null=True, blank=True)
    number_of_employees = models.IntegerField(null=True, blank=True)
    annual_revenue = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Annual revenue in ETB"
    )
    
    # Compliance
    compliance_officer_name = models.CharField(max_length=255, blank=True)
    compliance_officer_email = models.EmailField(blank=True)
    
    # Status
    onboarding_completed = models.BooleanField(default=False)
    onboarding_step = models.IntegerField(default=1)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'issuer_profiles'
        verbose_name = 'Issuer Profile'
        verbose_name_plural = 'Issuer Profiles'
    
    def __str__(self):
        return f"Issuer Profile: {self.user.username}"


class KYCDocument(models.Model):
    """
    KYC document management with AI/OCR processing
    """
    DOCUMENT_TYPE_CHOICES = [
        ('national_id', 'National ID'),
        ('passport', 'Passport'),
        ('driving_license', 'Driving License'),
        ('business_license', 'Business License'),
        ('tax_certificate', 'Tax Certificate'),
        ('incorporation_cert', 'Certificate of Incorporation'),
        ('proof_of_address', 'Proof of Address'),
        ('financial_statement', 'Financial Statement'),
        ('other', 'Other'),
    ]
    
    STATUS_CHOICES = [
        ('pending', 'Pending Review'),
        ('verified', 'Verified'),
        ('rejected', 'Rejected'),
        ('expired', 'Expired'),
    ]
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='kyc_documents')
    company = models.ForeignKey(Company, on_delete=models.CASCADE, null=True, blank=True, related_name='kyc_documents')
    
    document_type = models.CharField(max_length=50, choices=DOCUMENT_TYPE_CHOICES)
    document_number = models.CharField(max_length=100, blank=True)
    document_file = models.FileField(upload_to='kyc_documents/%Y/%m/')
    ipfs_hash = models.CharField(max_length=100, null=True, blank=True)
    
    # OCR/AI processing
    ocr_processed = models.BooleanField(default=False)
    ocr_data = models.JSONField(null=True, blank=True)
    ai_verification_score = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="AI verification confidence score (0-100)"
    )
    
    # Verification
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    verified_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='verified_documents'
    )
    verified_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True)
    
    # Expiration
    issue_date = models.DateField(null=True, blank=True)
    expiry_date = models.DateField(null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'kyc_documents'
        verbose_name = 'KYC Document'
        verbose_name_plural = 'KYC Documents'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.get_document_type_display()} - {self.user.username}"
    
    @property
    def is_expired(self):
        from datetime import date
        return self.expiry_date and self.expiry_date < date.today()
