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

AuthnData getAuthnData(final ProtoChallenge challenge) async {
  return // data from passport
}

main() {
  try {
    var client = new PortClient(serverUrl, httpClient: httpClient);
    client.onConnectionError  = handleConnectionError;
    client.onDG1FileRequested = handleDG1Request;

    await client.register((challenge) async {
      return getAuthnData(challenge);
    });

    await client.login((challenge) async {
      return getAuthnData(challenge);
    });

    final srvGreeting = await client.requestGreeting();
  } catch(e) {
    // handle error
  }
}
```