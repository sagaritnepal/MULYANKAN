import { User, UserRoleAssignment } from '@prisma/client';

type UserWithRoles = User & { roleAssignments: UserRoleAssignment[] };

/**
 * Strips fields a client never needs — fcmToken, and passwordHash (never,
 * ever send this one) — and flattens the roleAssignments join table (see
 * schema.prisma) into a plain `roles` string array, matching the API
 * shape the mobile app expects.
 */
export function serializeUser(user: UserWithRoles) {
  const { fcmToken: _fcmToken, passwordHash: _passwordHash, roleAssignments, ...safe } = user;
  return { ...safe, roles: roleAssignments.map((r) => r.role) };
}
