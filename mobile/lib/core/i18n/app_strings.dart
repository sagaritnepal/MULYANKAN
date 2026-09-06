/// Hand-rolled localisation rather than `flutter_localizations` + ARB
/// codegen: the string set is small, and a plain typed class means a
/// missing translation is a compile error instead of a silent fallback
/// to the key at runtime.
///
/// Coverage is partial while Phase 3 is in progress: auth, navigation,
/// the vehicle feed and the bidding screens switch. The request form,
/// dashboard, showroom setup and result screens still read their copy
/// literally and stay English — nothing breaks, they just don't switch.
library;

enum AppLocale {
  en('en', 'English'),
  ne('ne', 'नेपाली');

  const AppLocale(this.code, this.label);

  /// Matches the `language` column on User and the API's
  /// UpdateMeDto @IsIn(['en', 'ne']).
  final String code;

  /// Always shown in the language's own script, never translated.
  final String label;

  static AppLocale fromCode(String? code) => AppLocale.values.firstWhere(
    (l) => l.code == code,
    orElse: () => AppLocale.en,
  );
}

abstract class AppStrings {
  const AppStrings();

  static const Map<AppLocale, AppStrings> _byLocale = {
    AppLocale.en: _EnStrings(),
    AppLocale.ne: _NeStrings(),
  };

  static AppStrings of(AppLocale locale) =>
      _byLocale[locale] ?? const _EnStrings();

  // ---- Auth ----
  String get logIn;
  String get signUp;
  String get emailAddress;
  String get password;
  String get fullNameOptional;
  String get show;
  String get hide;
  String get forgotPassword;
  String get or;
  String get logInWithPhone;
  String get noAccountPrompt;
  String get haveAccountPrompt;
  String get enterBothFields;
  String get couldNotSignIn;

  // ---- Navigation ----
  String get navFeed;
  String get navDashboard;
  String get navPost;
  String get navInbox;

  // ---- Shared ----
  String get tryAgain;
  String get refresh;
  String get km;
  String get cc;

  // ---- Feed ----
  String get feedLoadFailed;
  String get feedEmptyTitle;
  String get feedEmptyDetail;
  String get interested;
  String get bid;
  String get joinLiveBidding;
  String get yours;
  String get live;
  String get topBid;
  String get noBidsYet;
  String get interestRegistered;
  String get couldNotRegisterInterest;

  /// "3 bids" / "1 bid". Nepali has no distinct plural form here, so the
  /// numeral carries the count and the noun stays invariant.
  String bidCount(int n);

  /// "4 interested · 2 more to open live bidding"
  String interestedNeedMore(int interested, int needed);

  /// "4 interested · sealed bids"
  String interestedSealed(int interested);

  /// "4 interested" — the grid cell in the feed has no room for the
  /// longer forms above.
  String interestedShort(int interested);

  /// Takes the raw request status from the API.
  String biddingStatus(String status);

  // ---- Bidding ----
  String get biddingTitle;
  String get topBidLabel;
  String get yourSealedBidLabel;
  String get notBidYet;
  String get openBids;
  String get openBidsNote;
  String get liveOpenNoBids;
  String get sealedBiddingTitle;
  String get yourBid;
  String get placeBid;
  String get raiseBid;
  String get enterBidAmount;
  String get couldNotPlaceBid;
  String get couldNotLoadBidding;
  String get sealedBidSubmitted;
  String get you;

  /// "5 bidding"
  String biddingCount(int n);

  /// "More than Rs 4,50,000" — the amount arrives already formatted by
  /// formatNpr, which owns all money rendering.
  String mustBeatAmount(String formattedAmount);

  /// The sealed-mode explanation, which changes with how many more
  /// participants are needed to open live bidding.
  String sealedExplanation(int needed);
}

class _EnStrings extends AppStrings {
  const _EnStrings();

  @override
  String get logIn => 'Log in';
  @override
  String get signUp => 'Sign up';
  @override
  String get emailAddress => 'Email address';
  @override
  String get password => 'Password';
  @override
  String get fullNameOptional => 'Full name (optional)';
  @override
  String get show => 'Show';
  @override
  String get hide => 'Hide';
  @override
  String get forgotPassword => 'Forgot password?';
  @override
  String get or => 'OR';
  @override
  String get logInWithPhone => 'Log in with phone number';
  @override
  String get noAccountPrompt => "Don't have an account? ";
  @override
  String get haveAccountPrompt => 'Already have an account? ';
  @override
  String get enterBothFields => 'Enter both email and password';
  @override
  String get couldNotSignIn => 'Could not sign in';

  @override
  String get navFeed => 'Feed';
  @override
  String get navDashboard => 'Dashboard';
  @override
  String get navPost => 'Post';
  @override
  String get navInbox => 'Inbox';

  @override
  String get tryAgain => 'Try again';
  @override
  String get refresh => 'Refresh';
  @override
  String get km => 'km';
  @override
  String get cc => 'cc';

  @override
  String get feedLoadFailed => 'Could not load vehicles';
  @override
  String get feedEmptyTitle => 'No vehicles yet';
  @override
  String get feedEmptyDetail =>
      'Vehicles posted by any showroom will appear here.';
  @override
  String get interested => 'Interested';
  @override
  String get bid => 'Bid';
  @override
  String get joinLiveBidding => 'Join live bidding';
  @override
  String get yours => 'Yours';
  @override
  String get live => 'LIVE';
  @override
  String get topBid => 'top bid';
  @override
  String get noBidsYet => 'No bids yet';
  @override
  String get interestRegistered =>
      'Marked as interested — you will be notified when bidding opens';
  @override
  String get couldNotRegisterInterest => 'Could not register interest';

  @override
  String bidCount(int n) => n == 1 ? '1 bid' : '$n bids';
  @override
  String interestedNeedMore(int interested, int needed) =>
      '$interested interested · $needed more to open live bidding';
  @override
  String interestedSealed(int interested) =>
      '$interested interested · sealed bids';
  @override
  String interestedShort(int interested) => '$interested interested';
  @override
  String biddingStatus(String status) => 'Bidding $status';

  @override
  String get biddingTitle => 'Bidding';
  @override
  String get topBidLabel => 'TOP BID';
  @override
  String get yourSealedBidLabel => 'YOUR SEALED BID';
  @override
  String get notBidYet => 'Not bid yet';
  @override
  String get openBids => 'Open bids';
  @override
  String get openBidsNote => 'Every participant sees these amounts.';
  @override
  String get liveOpenNoBids =>
      'Live bidding is open. No bids on the board yet — the first one sets the floor.';
  @override
  String get sealedBiddingTitle => 'Sealed bidding';
  @override
  String get yourBid => 'Your bid';
  @override
  String get placeBid => 'Place bid';
  @override
  String get raiseBid => 'Raise bid';
  @override
  String get enterBidAmount => 'Enter a bid amount';
  @override
  String get couldNotPlaceBid => 'Could not place bid';
  @override
  String get couldNotLoadBidding => 'Could not load bidding';
  @override
  String get sealedBidSubmitted => 'Sealed bid submitted';
  @override
  String get you => 'you';

  @override
  String biddingCount(int n) => '$n bidding';
  @override
  String mustBeatAmount(String formattedAmount) => 'More than $formattedAmount';
  @override
  String sealedExplanation(int needed) => needed > 0
      ? 'Other bids are hidden. Once $needed more ${needed == 1 ? 'valuer' : 'valuers'} '
            'bid or show interest, this vehicle switches to live bidding and every '
            'amount — including yours — becomes visible to all bidders.'
      : 'Other bids are hidden. This vehicle is about to switch to live bidding.';
}

/// Nepali copy drafted here and NOT yet reviewed by a native speaker.
/// The trade vocabulary especially — मूल्यांकन, बोली, सवारी — should be
/// checked against what dealers actually say on a showroom floor.
class _NeStrings extends AppStrings {
  const _NeStrings();

  @override
  String get logIn => 'लग इन';
  @override
  String get signUp => 'साइन अप';
  @override
  String get emailAddress => 'इमेल ठेगाना';
  @override
  String get password => 'पासवर्ड';
  @override
  String get fullNameOptional => 'पूरा नाम (वैकल्पिक)';
  @override
  String get show => 'देखाउने';
  @override
  String get hide => 'लुकाउने';
  @override
  String get forgotPassword => 'पासवर्ड बिर्सनुभयो?';
  @override
  String get or => 'वा';
  @override
  String get logInWithPhone => 'फोन नम्बरबाट लग इन';
  @override
  String get noAccountPrompt => 'खाता छैन? ';
  @override
  String get haveAccountPrompt => 'पहिले नै खाता छ? ';
  @override
  String get enterBothFields => 'इमेल र पासवर्ड दुवै भर्नुहोस्';
  @override
  String get couldNotSignIn => 'साइन इन गर्न सकिएन';

  @override
  String get navFeed => 'सवारी';
  @override
  String get navDashboard => 'ड्यासबोर्ड';
  @override
  String get navPost => 'पोस्ट';
  @override
  String get navInbox => 'इनबक्स';

  @override
  String get tryAgain => 'फेरि प्रयास गर्नुहोस्';
  @override
  String get refresh => 'रिफ्रेस';
  @override
  String get km => 'कि.मी.';
  @override
  String get cc => 'सी.सी.';

  @override
  String get feedLoadFailed => 'सवारी लोड गर्न सकिएन';
  @override
  String get feedEmptyTitle => 'अझै कुनै सवारी छैन';
  @override
  String get feedEmptyDetail => 'कुनै पनि शोरूमले राखेका सवारी यहाँ देखिनेछन्।';
  @override
  String get interested => 'इच्छुक';
  @override
  String get bid => 'बोली';
  @override
  String get joinLiveBidding => 'लाइभ बोलीमा सहभागी';
  @override
  String get yours => 'तपाईंको';
  @override
  String get live => 'लाइभ';
  @override
  String get topBid => 'उच्च बोली';
  @override
  String get noBidsYet => 'अझै बोली छैन';
  @override
  String get interestRegistered => 'इच्छुक जनाइयो — बोली खुल्दा जानकारी दिइनेछ';
  @override
  String get couldNotRegisterInterest => 'इच्छुक जनाउन सकिएन';

  @override
  String bidCount(int n) => '$n बोली';
  @override
  String interestedNeedMore(int interested, int needed) =>
      '$interested इच्छुक · लाइभ बोली खोल्न $needed जना बाँकी';
  @override
  String interestedSealed(int interested) => '$interested इच्छुक · गोप्य बोली';
  @override
  String interestedShort(int interested) => '$interested इच्छुक';
  @override
  String biddingStatus(String status) => 'बोली $status';

  @override
  String get biddingTitle => 'बोली';
  @override
  String get topBidLabel => 'उच्च बोली';
  @override
  String get yourSealedBidLabel => 'तपाईंको गोप्य बोली';
  @override
  String get notBidYet => 'बोली लगाइएको छैन';
  @override
  String get openBids => 'खुला बोली';
  @override
  String get openBidsNote => 'यी रकम सबै सहभागीले देख्छन्।';
  @override
  String get liveOpenNoBids =>
      'लाइभ बोली खुला छ। अझै कुनै बोली आएको छैन — पहिलो बोलीले आधार तय गर्छ।';
  @override
  String get sealedBiddingTitle => 'गोप्य बोली';
  @override
  String get yourBid => 'तपाईंको बोली';
  @override
  String get placeBid => 'बोली राख्नुहोस्';
  @override
  String get raiseBid => 'बोली बढाउनुहोस्';
  @override
  String get enterBidAmount => 'बोली रकम भर्नुहोस्';
  @override
  String get couldNotPlaceBid => 'बोली राख्न सकिएन';
  @override
  String get couldNotLoadBidding => 'बोली लोड गर्न सकिएन';
  @override
  String get sealedBidSubmitted => 'गोप्य बोली पेश भयो';
  @override
  String get you => 'तपाईं';

  @override
  String biddingCount(int n) => '$n जना बोलीमा';
  @override
  String mustBeatAmount(String formattedAmount) => '$formattedAmount भन्दा बढी';
  @override
  String sealedExplanation(int needed) => needed > 0
      ? 'अरूको बोली लुकाइएको छ। अझै $needed जनाले बोली लगाए वा इच्छुक जनाए पछि '
            'यो सवारी लाइभ बोलीमा जान्छ, र तपाईंको सहित सबै रकम सबै बोलीकर्ताले देख्नेछन्।'
      : 'अरूको बोली लुकाइएको छ। यो सवारी लाइभ बोलीमा जान लागेको छ।';
}
