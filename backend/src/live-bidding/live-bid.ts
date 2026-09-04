/**
 * Shapes and rules shared by everything that touches live bidding: the
 * REST board, the WebSocket broadcasts, and the activation check.
 */

/**
 * The product rule is "more than 2" engaged users, i.e. three or more.
 *
 * This is the default, not the last word: LiveBiddingService reads
 * LIVE_BIDDING_MIN_PARTICIPANTS from the environment and falls back to
 * this. Lowering it to 2 is how a small team can exercise live bidding
 * without three separate accounts; 1 removes sealed bidding altogether,
 * since the first bid would open the board.
 */
export const LIVE_BIDDING_MIN_PARTICIPANTS = 3;

export interface LiveBidSource {
  id: string;
  amountNpr: number | null;
  updatedAt: Date;
  valuer: { id: string; showroom: { name: string } | null };
}

/**
 * A bid as seen on the open board.
 *
 * `valuerId` is included so a client can highlight the viewer's own bid;
 * there is no server-side `isMine` because the same payload is broadcast
 * to a whole room at once. Personal names are deliberately left out — the
 * showroom is the identity another dealer bids against, and exposing
 * individual names buys nothing while leaking more than the blind-mode
 * default ever did.
 */
export function serializeLiveBid(q: LiveBidSource) {
  return {
    quoteId: q.id,
    valuerId: q.valuer.id,
    bidderLabel: q.valuer.showroom?.name ?? 'Independent valuer',
    amountNpr: q.amountNpr,
    at: q.updatedAt,
  };
}

/**
 * Distinct users engaged with a request. A submitted quote counts and so
 * does a bare inquiry; a `passed` quote does not — passing is explicitly
 * declining to engage, and counting it would push vehicles nobody wants
 * into live bidding.
 */
export function countParticipants(
  quotes: { valuerUserId: string; status: string }[],
  interests: { userId: string }[],
): number {
  const ids = new Set<string>();
  for (const q of quotes) {
    if (q.status === 'submitted') ids.add(q.valuerUserId);
  }
  for (const i of interests) ids.add(i.userId);
  return ids.size;
}
