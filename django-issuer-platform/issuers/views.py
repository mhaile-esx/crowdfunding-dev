from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.contrib.auth import authenticate, login, logout
from django.db import transaction
from .models import Company, IssuerProfile, KYCDocument
from .serializers import (
    UserRegistrationSerializer, UserSerializer, CompanySerializer,
    CompanyCreateSerializer, IssuerProfileSerializer, KYCDocumentSerializer,
    LoginSerializer, WalletConnectSerializer
)
from django.contrib.auth import get_user_model

User = get_user_model()


@api_view(['POST'])
@permission_classes([AllowAny])
def register_user(request):
    """
    Register a new user account
    """
    serializer = UserRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        return Response({
            'message': 'User registered successfully',
            'user': UserSerializer(user).data
        }, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def login_user(request):
    """
    User login with username/password
    """
    serializer = LoginSerializer(data=request.data)
    if serializer.is_valid():
        username = serializer.validated_data['username']
        password = serializer.validated_data['password']
        
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            login(request, user)
            return Response({
                'message': 'Login successful',
                'user': UserSerializer(user).data
            })
        else:
            return Response({
                'error': 'Invalid credentials'
            }, status=status.HTTP_401_UNAUTHORIZED)
    
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout_user(request):
    """
    User logout
    """
    logout(request)
    return Response({'message': 'Logout successful'})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def current_user(request):
    """
    Get current authenticated user
    """
    return Response(UserSerializer(request.user).data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def connect_wallet(request):
    """
    Connect MetaMask wallet to user account with EIP-191 signature verification
    
    SECURITY: Requires cryptographic signature to prevent account takeover
    Client must sign a message with their private key to prove wallet ownership
    Uses EIP-191 personal_sign standard with timestamp validation
    
    NOTE: Production deployment requires nonce-based authentication.
    See SECURITY_FIXES.md for implementation guide.
    """
    from web3 import Web3
    from eth_account.messages import encode_defunct
    import time
    import re
    from django.utils import timezone
    from datetime import timedelta
    
    serializer = WalletConnectSerializer(data=request.data)
    if serializer.is_valid():
        wallet_address = serializer.validated_data['wallet_address']
        signature = serializer.validated_data['signature']
        message = serializer.validated_data['message']
        
        # Verify the signature using EIP-191 standard
        try:
            w3 = Web3()
            
            # Encode message using EIP-191 (personal_sign standard)
            encoded_message = encode_defunct(text=message)
            
            # Recover address from signature
            recovered_address = w3.eth.account.recover_message(
                encoded_message,
                signature=signature
            )
            
            # Verify recovered address matches provided wallet address
            if recovered_address.lower() != wallet_address.lower():
                return Response({
                    'error': 'Signature verification failed. Address mismatch.'
                }, status=status.HTTP_401_UNAUTHORIZED)
            
            # Validate message format and extract timestamp
            if 'Login to CrowdfundChain at ' not in message:
                return Response({
                    'error': 'Invalid message format. Must include timestamp.'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Extract timestamp from message (format: "Login to CrowdfundChain at <timestamp>")
            try:
                timestamp_match = re.search(r'at (\d+)', message)
                if not timestamp_match:
                    return Response({
                        'error': 'Message must contain timestamp'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                message_timestamp = int(timestamp_match.group(1))
                current_timestamp = int(time.time() * 1000)  # milliseconds
                
                # Reject messages older than 5 minutes (300000 ms)
                MAX_AGE_MS = 300000
                age_ms = current_timestamp - message_timestamp
                
                if age_ms < 0:
                    return Response({
                        'error': 'Message timestamp is in the future'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                if age_ms > MAX_AGE_MS:
                    return Response({
                        'error': 'Message has expired. Please sign a new message.'
                    }, status=status.HTTP_401_UNAUTHORIZED)
                
            except (ValueError, AttributeError) as e:
                return Response({
                    'error': f'Invalid timestamp format: {str(e)}'
                }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            return Response({
                'error': f'Invalid signature: {str(e)}'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if wallet already connected to another user
        existing_user = User.objects.filter(wallet_address__iexact=wallet_address).first()
        
        if existing_user:
            if existing_user.id == request.user.id:
                from rest_framework_simplejwt.tokens import RefreshToken
                refresh = RefreshToken.for_user(existing_user)
                return Response({
                    'message': 'Wallet already connected to your account',
                    'user': UserSerializer(existing_user).data,
                    'access': str(refresh.access_token),
                    'refresh': str(refresh),
                })
            else:
                return Response({
                    'error': 'Wallet already connected to another account'
                }, status=status.HTTP_409_CONFLICT)
        else:
            # Connect external wallet (mobile wallet) to current authenticated user
            current_user = request.user
            if current_user.wallet_address:
                return Response({
                    'error': 'You already have a wallet connected. Disconnect first to connect a new one.'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            current_user.wallet_address = wallet_address
            current_user.save()
            
            from rest_framework_simplejwt.tokens import RefreshToken
            refresh = RefreshToken.for_user(current_user)
            
            return Response({
                'message': 'Mobile wallet connected successfully',
                'user': UserSerializer(current_user).data,
                'access': str(refresh.access_token),
                'refresh': str(refresh),
            }, status=status.HTTP_201_CREATED)
    
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)




@api_view(['POST'])
@permission_classes([IsAuthenticated])
def generate_wallet(request):
    """Generate a new blockchain wallet for the authenticated user"""
    user = request.user
    
    if user.wallet_address:
        return Response({
            'message': 'Wallet already exists',
            'wallet_address': user.wallet_address
        }, status=status.HTTP_200_OK)
    
    try:
        from blockchain.wallet_service import get_wallet_service
        
        wallet_service = get_wallet_service()
        wallet_data = wallet_service.generate_wallet()
        
        user.wallet_address = wallet_data['address']
        user.save()
        
        return Response({
            'message': 'Wallet generated successfully',
            'wallet_address': wallet_data['address'],
        }, status=status.HTTP_201_CREATED)
        
    except ValueError as e:
        return Response({
            'error': str(e),
            'hint': 'Contact administrator to configure WALLET_ENCRYPTION_KEY'
        }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    except Exception as e:
        return Response({
            'error': f'Failed to generate wallet: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def wallet_balance(request):
    """Get wallet balance for the authenticated user"""
    user = request.user
    
    if not user.wallet_address:
        return Response({'error': 'No wallet connected'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        from blockchain.wallet_service import get_wallet_service
        wallet_service = get_wallet_service()
        balance = wallet_service.get_balance(user.wallet_address)
        return Response(balance)
    except Exception as e:
        return Response({'error': f'Failed to get balance: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CompanyViewSet(viewsets.ModelViewSet):
    """
    ViewSet for company management
    """
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return CompanyCreateSerializer
        return CompanySerializer
    
    def get_queryset(self):
        # Handle swagger schema generation
        if getattr(self, 'swagger_fake_view', False):
            return Company.objects.none()
        
        user = self.request.user
        
        # Handle anonymous users
        if not user.is_authenticated:
            return Company.objects.none()
        
        if getattr(user, 'role', None) == 'admin':
            return Company.objects.all()
        return Company.objects.filter(user=user)
    
    @transaction.atomic
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
    
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def verify(self, request, pk=None):
        """
        Verify a company (admin only)
        """
        company = self.get_object()
        company.compliance_status = 'verified'
        company.save()
        
        return Response({
            'message': 'Company verified successfully',
            'company': CompanySerializer(company).data
        })
    
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def reject(self, request, pk=None):
        """
        Reject a company verification (admin only)
        """
        company = self.get_object()
        company.compliance_status = 'rejected'
        company.save()
        
        return Response({
            'message': 'Company verification rejected',
            'company': CompanySerializer(company).data
        })
    
    @action(detail=False, methods=['get'])
    def my_companies(self, request):
        """
        Get companies owned by current user
        """
        companies = Company.objects.filter(user=request.user)
        serializer = CompanySerializer(companies, many=True)
        return Response(serializer.data)


class IssuerProfileViewSet(viewsets.ModelViewSet):
    """
    ViewSet for issuer profile management
    """
    permission_classes = [IsAuthenticated]
    serializer_class = IssuerProfileSerializer
    
    def get_queryset(self):
        # Handle swagger schema generation
        if getattr(self, 'swagger_fake_view', False):
            return IssuerProfile.objects.none()
        
        user = self.request.user
        
        # Handle anonymous users
        if not user.is_authenticated:
            return IssuerProfile.objects.none()
        
        if getattr(user, 'role', None) == 'admin':
            return IssuerProfile.objects.all()
        return IssuerProfile.objects.filter(user=user)


class KYCDocumentViewSet(viewsets.ModelViewSet):
    """
    ViewSet for KYC document management
    """
    permission_classes = [IsAuthenticated]
    serializer_class = KYCDocumentSerializer
    
    def get_queryset(self):
        # Handle swagger schema generation
        if getattr(self, 'swagger_fake_view', False):
            return KYCDocument.objects.none()
        
        user = self.request.user
        
        # Handle anonymous users
        if not user.is_authenticated:
            return KYCDocument.objects.none()
        
        if getattr(user, 'role', None) in ['admin', 'compliance_officer']:
            return KYCDocument.objects.all()
        return KYCDocument.objects.filter(user=user)
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
    
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def verify(self, request, pk=None):
        """
        Verify a KYC document (admin/compliance officer only)
        """
        from django.utils import timezone
        
        document = self.get_object()
        document.status = 'verified'
        document.verified_by = request.user
        document.verified_at = timezone.now()
        document.save()
        
        # Update user KYC status
        user = document.user
        user.kyc_verified = True
        kyc_level = request.data.get('kyc_level', 'basic')
        if kyc_level in ['basic', 'enhanced', 'full']:
            user.kyc_level = kyc_level
        user.save()
        
        return Response({
            'message': 'KYC document verified successfully',
            'document': KYCDocumentSerializer(document).data
        })
    
    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def reject(self, request, pk=None):
        """
        Reject a KYC document (admin/compliance officer only)
        """
        document = self.get_object()
        document.status = 'rejected'
        document.verified_by = request.user
        document.rejection_reason = request.data.get('reason', 'Document rejected')
        document.save()
        
        return Response({
            'message': 'KYC document rejected',
            'document': KYCDocumentSerializer(document).data
        })
