import { ForbiddenException } from '@nestjs/common';
import { User } from '@prisma/client';

/**
 * Who owns a valuation request, and who is allowed to bid on it.
 *
 * A request has one of two kinds of seller:
 *
 * - **A recondition house** — `showroomId` is set, and every member of
 *   that showroom is the seller (the original dealer-to-dealer exchange
 *   flow: whoever is on shift can run the board).
 * - **A member of the public** — `showroomId` is null, and exactly one
 *   person is the seller: `createdByUserId`.
 *
 * This exists as one function because the naive check
 * `request.showroomId === user.showroomId` is a security hole once
 * public posts are allowed: both sides are null for any showroom-less
 * user, so every customer would be treated as the seller of every
 * public request — able to read the sealed board, close the window, pick
 * a winner and cancel someone else's bike.
 */
export interface OwnableRequest {
  showroomId: string | null;
  createdByUserId: string;
}

export function isSeller(request: OwnableRequest, user: Pick<User, 'id' | 'showroomId'>): boolean {
  if (request.showroomId === null) {
    return request.createdByUserId === user.id;
  }
  return user.showroomId !== null && user.showroomId === request.showroomId;
}

export function assertIsSeller(
  request: OwnableRequest,
  user: Pick<User, 'id' | 'showroomId'>,
): void {
  if (!isSeller(request, user)) {
    throw new ForbiddenException('Only the seller can do this');
  }
}

/**
 * How a seller is named to bidders. Recondition houses trade under
 * their business name; a member of the public stays anonymous, since
 * valuing a bike needs the bike, not the owner's identity.
 */
export function sellerLabel(request: { showroom?: { name: string } | null }): string {
  return request.showroom?.name ?? 'Private seller';
}

/**
 * Only recondition houses value vehicles. Membership of a showroom *is*
 * the credential — a member of the public has no showroom and must never
 * be able to bid, on their own bike or anyone else's.
 */
export function canBid(user: Pick<User, 'showroomId'>): boolean {
  return user.showroomId !== null;
}

/**
 * Business rule #8, generalised. A seller cannot bid on their own
 * vehicle, whichever kind of seller they are.
 */
export function assertCanBid(
  request: OwnableRequest,
  user: Pick<User, 'id' | 'showroomId'>,
): void {
  if (!canBid(user)) {
    throw new ForbiddenException('Only recondition houses can value a vehicle');
  }
  if (isSeller(request, user)) {
    throw new ForbiddenException('You cannot bid on your own vehicle');
  }
}
