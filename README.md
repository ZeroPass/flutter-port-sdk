## Port Library
Flutter implementation of Port client SDK.

## Usage
 1) Include `port` library in your project's `pubspec.yaml` file:  
```
dependencies:
  port:
    path: '<path_to_port_folder>'
```
 2) Run 
 ```
 flutter pub get
 ```
 
**Example:**  
*Note: See also [example](example) app*

```dart
import 'package:port/port.dart';

PassportData getPassportData(final ProtoChallenge challenge) async {
  return PassportData(...)// data from passport
}

main() {
  try {
    var client = new PortClient(serverUrl, httpClient: httpClient);
    client.onConnectionError  = handleConnectionError;
    client.onDG1FileRequested = handleDG1Request;

    await client.register(usedId, sod, dg15: dg15, dg14:dg14);

    var result = await client.getAssertion(uid, (challenge) async {
      final data = getPassportData(challenge);
      return data.csig!;
    });

  } catch(e) {
    // handle error
    if(e is PortError) {
      if (e == PortError.accountAlreadyRegistered) error = 'Account already exists!';
      ...
    }
    else {
      ...
    }
  }
}
```