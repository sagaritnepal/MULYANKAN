import {
  LIVE_BIDDING_MIN_PARTICIPANTS,
  countParticipants,
  serializeLiveBid,
} from './live-bid';

describe('countParticipants', () => {
  it('counts a submitted quote as engagement', () => {
    expect(countParticipants([{ valuerUserId: 'a', status: 'submitted' }], [])).toBe(1);
  });

  it('does not count a passed quote — passing is declining to engage', () => {
    expect(countParticipants([{ valuerUserId: 'a', status: 'passed' }], [])).toBe(0);
  });

  it('does not count a withdrawn quote', () => {
    expect(countParticipants([{ valuerUserId: 'a', status: 'withdrawn' }], [])).toBe(0);
  });

  it('counts a bare inquiry', () => {
    expect(countParticipants([], [{ userId: 'a' }])).toBe(1);
  });

  it('counts a user once when they both inquired and quoted', () => {
    expect(
      countParticipants([{ valuerUserId: 'a', status: 'submitted' }], [{ userId: 'a' }]),
    ).toBe(1);
  });

  it('unions distinct quoters and inquirers', () => {
    expect(
      countParticipants(
        [
          { valuerUserId: 'a', status: 'submitted' },
          { valuerUserId: 'b', status: 'passed' },
        ],
        [{ userId: 'c' }, { userId: 'a' }],
      ),
    ).toBe(2); // a and c; b passed
  });

  it('reaches the threshold on three inquiries alone', () => {
    const n = countParticipants([], [{ userId: 'a' }, { userId: 'b' }, { userId: 'c' }]);
    expect(n).toBeGreaterThanOrEqual(LIVE_BIDDING_MIN_PARTICIPANTS);
  });

  it('treats "more than 2" as three', () => {
    expect(LIVE_BIDDING_MIN_PARTICIPANTS).toBe(3);
  });
});

describe('serializeLiveBid', () => {
  const base = {
    id: 'q1',
    amountNpr: 450000,
    updatedAt: new Date('2026-09-04T10:00:00Z'),
  };

  it('labels a bidder by showroom, never by personal name', () => {
    const out = serializeLiveBid({
      ...base,
      valuer: { id: 'u1', showroom: { name: 'G&G Auto' } },
    });
    expect(out.bidderLabel).toBe('G&G Auto');
    expect(JSON.stringify(out)).not.toContain('name');
  });

  it('falls back for a valuer with no showroom', () => {
    const out = serializeLiveBid({ ...base, valuer: { id: 'u1', showroom: null } });
    expect(out.bidderLabel).toBe('Independent valuer');
  });

  it('exposes valuerId so a client can mark its own bid, but no isMine flag', () => {
    const out = serializeLiveBid({
      ...base,
      valuer: { id: 'u1', showroom: null },
    });
    expect(out.valuerId).toBe('u1');
    expect(out).not.toHaveProperty('isMine');
  });
});
