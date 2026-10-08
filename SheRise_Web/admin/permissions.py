"""Role and permission checks for Admin APIs."""

ROLE_PERMISSIONS = {
    "super_admin": {"admin_auth", "admin_sessions_all", "monitor_read", "safety_read", "safety_write", "audit_read", "user_moderate", "job_moderate"},
    "safety_admin": {"admin_auth", "monitor_read", "safety_read", "safety_write", "job_moderate"},
    "operations_admin": {"admin_auth", "monitor_read", "user_moderate", "job_moderate"},
    "support_readonly": {"admin_auth", "monitor_read", "safety_read"},
}

VALID_ROLES = frozenset(ROLE_PERMISSIONS)


def role_is_valid(role):
    return role in VALID_ROLES


def has_permission(role, permission):
    return permission in ROLE_PERMISSIONS.get(role, set())
