import { ForbiddenException } from '@nestjs/common';
import { assertCanBid, assertIsSeller, canBid, isSeller } from './request-ownership';

/**
 * These are the guards that stand between a customer and someone else's
 * sealed offers, so every branch gets a test — including the null/null
 * case that the old field comparison got wrong.
 */
describe('isSeller', () => {
  const dealerPost = { showroomId: 's1', createdByUserId: 'staff1' };
  const publicPost = { showroomId: null, createdByUserId: 'cust1' };

  describe('a recondition house posted it', () => {
    it('any member of that showroom is the seller', () => {
      expect(isSeller(dealerPost, { id: 'staff2', showroomId: 's1' })).toBe(true);
    });

    it('a member of another showroom is not', () => {
      expect(isSeller(dealerPost, { id: 'other', showroomId: 's2' })).toBe(false);
    });

    it('a customer with no showroom is not', () => {
      expect(isSeller(dealerPost, { id: 'cust1', showroomId: null })).toBe(false);
    });
  });

  describe('a member of the public posted it', () => {
    it('the person who posted it is the seller', () => {
      expect(isSeller(publicPost, { id: 'cust1', showroomId: null })).toBe(true);
    });

    // The whole reason this module exists: null === null used to make
    // every showroom-less user the seller of every public request.
    it('a DIFFERENT customer with no showroom is NOT the seller', () => {
      expect(isSeller(publicPost, { id: 'cust2', showroomId: null })).toBe(false);
    });

    it('a dealer is not the seller', () => {
      expect(isSeller(publicPost, { id: 'staff1', showroomId: 's1' })).toBe(false);
    });
  });

  it('assertIsSeller throws for a non-seller', () => {
    expect(() => assertIsSeller(publicPost, { id: 'cust2', showroomId: null })).toThrow(
      ForbiddenException,
    );
    expect(() => assertIsSeller(publicPost, { id: 'cust1', showroomId: null })).not.toThrow();
  });
});

describe('canBid', () => {
  it('a showroom member can bid', () => {
    expect(canBid({ showroomId: 's1' })).toBe(true);
  });

  it('a member of the public cannot', () => {
    expect(canBid({ showroomId: null })).toBe(false);
  });
});

describe('assertCanBid', () => {
  const publicPost = { showroomId: null, createdByUserId: 'cust1' };
  const dealerPost = { showroomId: 's1', createdByUserId: 'staff1' };

  it('lets a dealer bid on a public bike', () => {
    expect(() => assertCanBid(publicPost, { id: 'staff1', showroomId: 's1' })).not.toThrow();
  });

  it('refuses a customer bidding on their own bike', () => {
    expect(() => assertCanBid(publicPost, { id: 'cust1', showroomId: null })).toThrow(
      ForbiddenException,
    );
  });

  it('refuses a customer bidding on anyone else\'s bike', () => {
    expect(() => assertCanBid(publicPost, { id: 'cust2', showroomId: null })).toThrow(
      ForbiddenException,
    );
  });

  it('refuses a showroom bidding on its own post (rule #8)', () => {
    expect(() => assertCanBid(dealerPost, { id: 'staff2', showroomId: 's1' })).toThrow(
      ForbiddenException,
    );
  });

  it('lets another showroom bid on a dealer post', () => {
    expect(() => assertCanBid(dealerPost, { id: 'other', showroomId: 's2' })).not.toThrow();
  });
});
