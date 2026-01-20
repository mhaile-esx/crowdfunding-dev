# Backoffice Administration API

This module provides REST API endpoints for backoffice administrators to review and manage issuer submissions, KYC documents, and campaign approvals.

## Authentication

All backoffice endpoints require JWT authentication with admin or compliance officer role.

```bash
# Get JWT token
curl -X POST http://localhost:8000/api/auth/token/ \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "password"}'

# Use token in requests
curl -H "Authorization: Bearer <access_token>" \
  http://localhost:8000/api/backoffice/dashboard/stats/
```

## Dashboard Endpoints

### Get Dashboard Statistics
```
GET /api/backoffice/dashboard/stats/
```

Returns summary statistics for the admin dashboard:
- Pending issuers, KYC documents, campaigns
- Active campaigns
- Total issuers and investors
- Total funding raised
- Recent activities

### Get Pending Review Queue
```
GET /api/backoffice/dashboard/pending_queue/
```

Returns all items pending review grouped by type (issuers, KYC documents, campaigns).

## Issuer Review Endpoints

### List All Issuers
```
GET /api/backoffice/issuers/
```

Query parameters:
- `status`: `pending` or `verified`
- `sector`: Filter by sector
- `search`: Search by name or TIN

### Get Issuer Details
```
GET /api/backoffice/issuers/{id}/
```

### Review Issuer
```
POST /api/backoffice/issuers/{id}/review/
```

Request body:
```json
{
  "action": "verify|reject|request_documents",
  "rejection_reason": "Optional reason for rejection",
  "required_documents": ["document1", "document2"]
}
```

Actions:
- `verify`: Approve the issuer
- `reject`: Reject with reason
- `request_documents`: Request additional documents

### Get Issuer Documents
```
GET /api/backoffice/issuers/{id}/documents/
```

### Get Issuer Campaigns
```
GET /api/backoffice/issuers/{id}/campaigns/
```

## KYC Document Review Endpoints

### List All KYC Documents
```
GET /api/backoffice/kyc/
```

Query parameters:
- `status`: `pending`, `verified`, `rejected`, `expired`
- `document_type`: Filter by document type

### Get KYC Document Details
```
GET /api/backoffice/kyc/{id}/
```

### Review KYC Document
```
POST /api/backoffice/kyc/{id}/review/
```

Request body:
```json
{
  "action": "approve|reject",
  "kyc_level": "basic|enhanced|premium",
  "rejection_reason": "Optional reason for rejection"
}
```

When approving:
- Document status set to `verified`
- User's KYC level updated to specified level
- User's `kyc_verified` flag set to true

### Get KYC Statistics
```
GET /api/backoffice/kyc/statistics/
```

Returns document counts by status and type.

## Campaign Review Endpoints

### List All Campaigns
```
GET /api/backoffice/campaigns/
```

Query parameters:
- `status`: `draft`, `pending`, `active`, `successful`, `failed`, `cancelled`
- `approved`: `true` or `false`
- `search`: Search by title or company name

### Get Campaign Details
```
GET /api/backoffice/campaigns/{id}/
```

### Review Campaign
```
POST /api/backoffice/campaigns/{id}/review/
```

Request body:
```json
{
  "action": "approve|reject|request_changes",
  "rejection_reason": "Optional reason for rejection",
  "review_notes": "Notes for changes requested"
}
```

Actions:
- `approve`: Approve campaign for launch (requires verified issuer)
- `reject`: Reject and cancel campaign
- `request_changes`: Request modifications before approval

### Activate Campaign
```
POST /api/backoffice/campaigns/{id}/activate/
```

Activates an approved campaign:
- Sets status to `active`
- Sets start_date to now
- Sets end_date based on campaign duration
- Marks issuer's company as having active campaign

Requirements:
- Campaign must be approved
- Campaign cannot already be active

### Get Campaign Statistics
```
GET /api/backoffice/campaigns/statistics/
```

Returns campaign counts by status, total goals, and funding raised.

## User Management Endpoints

### List All Users
```
GET /api/backoffice/users/
```

Query parameters:
- `role`: Filter by role
- `kyc_verified`: `true` or `false`
- `search`: Search by username, email, or name

### Get User Details
```
GET /api/backoffice/users/{id}/
```

### Change User Role
```
POST /api/backoffice/users/{id}/change_role/
```

Request body:
```json
{
  "role": "admin|compliance_officer|custodian|regulator|issuer|investor"
}
```

### Toggle User Active Status
```
POST /api/backoffice/users/{id}/toggle_active/
```

Enables/disables a user account. Cannot deactivate own account.

## Permissions

| Endpoint Group | Required Role |
|---------------|---------------|
| Dashboard | Admin, Compliance Officer |
| Issuer Review | Admin, Compliance Officer |
| KYC Review | Admin, Compliance Officer |
| Campaign Review | Admin, Compliance Officer |
| User Management | Admin only |

## Error Responses

All endpoints return standard error format:

```json
{
  "error": "Error message description"
}
```

HTTP Status Codes:
- 200: Success
- 400: Bad Request (validation error)
- 401: Unauthorized (not authenticated)
- 403: Forbidden (insufficient permissions)
- 404: Not Found
