import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: JavaScriptIntegrationChallengePage(),
    );
  }
}

class JavaScriptIntegrationChallengePage extends StatefulWidget {
  const JavaScriptIntegrationChallengePage({super.key});

  @override
  State<JavaScriptIntegrationChallengePage> createState() =>
      _JavaScriptIntegrationChallengePageState();
}

class _JavaScriptIntegrationChallengePageState
    extends State<JavaScriptIntegrationChallengePage> {
  late final WebViewController _controller;

  bool _isLoading = true;
  String _totalFromJs = '-';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)

      // ✅ Step 2: Receive data from JS on name "FlutterChannel"
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          setState(() {
            _totalFromJs = message.message; // e.g. "Total: $120"
          });
        },
      )

      // ✅ Events + Navigation control
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isLoading = true),
          onPageFinished: (url) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            final url = request.url;

            // allow local asset / internal schemes
            if (!url.startsWith('http')) return NavigationDecision.navigate;

            // allow flutter + docs.flutter
            if (url.startsWith('https://flutter.dev') ||
                url.startsWith('https://docs.flutter.dev')) {
              return NavigationDecision.navigate;
            }

            return NavigationDecision.prevent;
          },
        ),
      )

      // ✅ Step 1: Show HTML inside webview (from assets/index.html)
      ..loadFlutterAsset('assets/index.html');
  }

  int _extractTotalNumber(String text) {
    // text example: "Total: $120"
    final match = RegExp(r'(\d+)').firstMatch(text);
    return int.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  // ✅ Step 3: Send data from flutter to JS via "updateTotalFromFlutter"
  Future<void> _sendPlus100ToJs() async {
    final current = _extractTotalNumber(_totalFromJs);
    final newTotal = current + 100;

    await _controller.runJavaScript("updateTotalFromFlutter($newTotal);");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JavaScript Integration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _controller.canGoBack()) await _controller.goBack();
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () async {
              if (await _controller.canGoForward())
                await _controller.goForward();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: WebViewWidget(controller: _controller)),

              // Flutter UI part (Step 2 + Step 3)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Received from JS: $_totalFromJs'),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _totalFromJs == '-' ? null : _sendPlus100ToJs,
                        child: const Text('Send +100 total from Flutter to JS'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
