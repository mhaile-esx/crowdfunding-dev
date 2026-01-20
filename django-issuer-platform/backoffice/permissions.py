"""
Custom permissions for backoffice administration
"""
from rest_framework import permissions


class IsAdminOrComplianceOfficer(permissions.BasePermission):
    """
    Allow access only to admin or compliance officer users
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.is_staff or getattr(request.user, 'role', '') in ['admin', 'compliance_officer']


class IsAdminOnly(permissions.BasePermission):
    """
    Allow access only to admin users
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return request.user.is_staff or getattr(request.user, 'role', '') == 'admin'


class IsRegulator(permissions.BasePermission):
    """
    Allow access to regulators (read-only access for auditing)
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return getattr(request.user, 'role', '') in ['admin', 'regulator']
