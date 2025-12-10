# GlucoseStandby

A small application to let you see your Dexcom CGM blood glucose data in the background.

# Can I trust this app?

Asking the creator of the app is bold... but yes you can. It's open source and only requests Dexcom's servers. (I don't even track analytics; I know people's health data can be sensitive to some)

The package I use to make these requests (and was also made by me) is [dexcom](https://pub.dev/packages/dexcom) (shameless plug I know). Here's a snippet of the endpoints:

```dart
// Lists all the endpoints for the requests
Map _dexcomData = {
  "endpoint": {
    "session": "General/LoginPublisherAccountById",
    "account": "General/AuthenticatePublisherAccount",
    "data": "Publisher/ReadPublisherLatestGlucoseValues"
  }
};

String _getBaseUrl(DexcomRegion region) {
  switch (region) {
    case DexcomRegion.us:
      return "https://share2.dexcom.com/ShareWebServices/Services";
    case DexcomRegion.ous:
      return "https://shareous1.dexcom.com/ShareWebServices/Services";
    case DexcomRegion.jp:
      return "https://share.dexcom.jp/ShareWebServices/Services";
  }
}
```

The package uses only these URLs and endpoints for its data. Note that your username *and* password are needed for these endpoints, and those are stored in plain text *on your device*.

For a detailed breakdown of these endpoints, check out my [documentation](https://github.com/Calebh101/dexcom/blob/main/README.md) on this. (Yes I made this too haha)