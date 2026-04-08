import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/models.dart';
import '../../services/avatar_try_on_service.dart';
import '../../services/backend_commerce_service.dart';
import '../../services/three_d_asset_pipeline_service.dart';
import '../../theme.dart';
import 'live_ar_try_on_screen.dart';

class AvatarTryOnScreen extends StatefulWidget {
  const AvatarTryOnScreen({
    super.key,
    required this.product,
    required this.accentColor,
  });

  final Product product;
  final Color accentColor;

  @override
  State<AvatarTryOnScreen> createState() => _AvatarTryOnScreenState();
}

class _AvatarTryOnScreenState extends State<AvatarTryOnScreen> {
  final BackendCommerceService _backend = BackendCommerceService();
  final AvatarTryOnService _avatarService = const AvatarTryOnService();
  final ThreeDAssetPipelineService _assetPipeline =
      ThreeDAssetPipelineService.instance;

  late final WebViewController _webViewController;
  BodyProfile? _bodyProfile;
  String _garmentModelUrl = '';
  String _fallbackImageUrl = '';
  bool _loading = true;
  bool _failed3d = false;
  double _zoom = 1;
  bool _isFront = true;

  String get _avatarModelUrl {
    final mapped = widget.product.attributes['avatarModelUrl']?.trim() ?? '';
    if (mapped.isNotEmpty) {
      return mapped;
    }
    return 'https://modelviewer.dev/shared-assets/models/Astronaut.glb';
  }

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (_) {
            if (!mounted) {
              return;
            }
            setState(() => _failed3d = true);
          },
          onPageFinished: (_) async {
            await _pushProfileToWeb();
            if (!mounted) {
              return;
            }
            setState(() => _loading = false);
          },
        ),
      );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    BodyProfile? profile;
    if (_backend.isConfigured) {
      try {
        profile = await _backend.getBodyProfile();
      } catch (_) {
        profile = null;
      }
    }
    if (!mounted) {
      return;
    }
    _bodyProfile = profile;
    final resolved = await _assetPipeline.resolveForProduct(widget.product);
    _garmentModelUrl = resolved.modelUrl;
    _fallbackImageUrl = resolved.fallbackImageUrl;
    await _webViewController.loadHtmlString(_buildHtml());
  }

  String _buildHtml() {
    final avatarUrl = _avatarModelUrl.replaceAll("'", r"\'");
    final garmentUrl = _garmentModelUrl.replaceAll("'", r"\'");
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <script type="module" src="https://unpkg.com/@google/model-viewer/dist/model-viewer.min.js"></script>
  <style>
    html, body { margin:0; padding:0; width:100%; height:100%; background:#f8f6ef; overflow:hidden; }
    .stack { position:relative; width:100%; height:100%; }
    model-viewer { position:absolute; inset:0; width:100%; height:100%; background:transparent; }
    #garment { pointer-events:none; opacity:0.93; }
  </style>
</head>
<body>
  <div class="stack">
    <model-viewer id="avatar" src="$avatarUrl" camera-controls shadow-intensity="1.2" exposure="1.0" disable-pan></model-viewer>
    <model-viewer id="garment" src="$garmentUrl" camera-controls disable-pan></model-viewer>
  </div>
  <script>
    const avatar = document.getElementById('avatar');
    const garment = document.getElementById('garment');
    let chest = 0.5, waist = 0.5, hip = 0.5, height = 1.0, zoom = 1.0, front = true;

    function applyTransform() {
      const torsoX = (0.86 + chest * 0.34).toFixed(3);
      const waistX = (0.86 + waist * 0.28).toFixed(3);
      const hipX = (0.86 + hip * 0.30).toFixed(3);
      const y = (height).toFixed(3);
      const z = ((torsoX * 0.66 + waistX * 0.20 + hipX * 0.14)).toFixed(3);
      avatar.scale = `\${torsoX} \${y} \${z}`;
      if (garment && garment.src) {
        garment.scale = `\${torsoX} \${y} \${z}`;
      }
      const orbit = front ? `0deg 72deg \${2.2 / zoom}m` : `180deg 72deg \${2.2 / zoom}m`;
      avatar.cameraOrbit = orbit;
      if (garment && garment.src) {
        garment.cameraOrbit = orbit;
      }
    }

    avatar.addEventListener('camera-change', () => {
      if (garment && garment.src) {
        garment.cameraOrbit = avatar.cameraOrbit;
      }
    });

    window.abzoraAvatar = {
      setBodyProfile: (profile) => {
        chest = Number(profile.chestMorph ?? 0.5);
        waist = Number(profile.waistMorph ?? 0.5);
        hip = Number(profile.hipMorph ?? 0.5);
        height = Number(profile.heightScale ?? 1.0);
        applyTransform();
      },
      setFront: (value) => { front = Boolean(value); applyTransform(); },
      setZoom: (value) => {
        zoom = Math.max(0.6, Math.min(2.0, Number(value) || 1.0));
        applyTransform();
      },
      capture: () => {
        try {
          const canvas = avatar.shadowRoot && avatar.shadowRoot.querySelector('canvas');
          if (!canvas) return '';
          return canvas.toDataURL('image/png');
        } catch (e) {
          return '';
        }
      }
    };
    applyTransform();
  </script>
</body>
</html>
''';
  }

  Future<void> _pushProfileToWeb() async {
    final params = _avatarService.mapFromProfile(_bodyProfile);
    final payload = jsonEncode({
      'heightScale': params.heightScale,
      'chestMorph': params.chestMorph,
      'waistMorph': params.waistMorph,
      'hipMorph': params.hipMorph,
    });
    await _webViewController.runJavaScript(
      "window.abzoraAvatar && window.abzoraAvatar.setBodyProfile($payload);",
    );
  }

  Future<void> _setFront(bool value) async {
    setState(() => _isFront = value);
    await _webViewController.runJavaScript(
      "window.abzoraAvatar && window.abzoraAvatar.setFront(${value ? 'true' : 'false'});",
    );
  }

  void _setZoom(double value) {
    setState(() => _zoom = value);
    _webViewController.runJavaScript(
      "window.abzoraAvatar && window.abzoraAvatar.setZoom(${value.toStringAsFixed(3)});",
    );
  }

  Future<void> _capture() async {
    final result = await _webViewController.runJavaScriptReturningResult(
      "window.abzoraAvatar && window.abzoraAvatar.capture ? window.abzoraAvatar.capture() : '';",
    );
    final value = result.toString();
    if (!mounted) {
      return;
    }
    final ok = value.contains('data:image/png');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          ok
              ? '3D screenshot captured in web context.'
              : 'Screenshot not supported here. Use Live AR capture fallback.',
        ),
      ),
    );
  }

  Future<void> _openFallback2d() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveArTryOnScreen(
          product: widget.product,
          accentColor: widget.accentColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6EF),
      appBar: AppBar(
        title: const Text('3D Avatar Try-On'),
        actions: [
          TextButton(
            onPressed: _openFallback2d,
            child: const Text('2D AR Fallback'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_failed3d)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.view_in_ar_rounded, size: 42),
                          const SizedBox(height: 10),
                          const Text(
                            '3D renderer unavailable on this device.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          if (_fallbackImageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _fallbackImageUrl,
                                height: 92,
                                width: 92,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          if (_fallbackImageUrl.isNotEmpty)
                            const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _openFallback2d,
                            child: const Text('Open 2D AR Try-On'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  WebViewWidget(controller: _webViewController),
                if (_loading && !_failed3d)
                  const Center(
                    child: CircularProgressIndicator(
                      color: AbzioTheme.accentColor,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFECE5CF))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _setFront(true),
                        icon: const Icon(
                          Icons.flip_camera_android_rounded,
                          size: 16,
                        ),
                        label: const Text('Front'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _setFront(false),
                        icon: const Icon(
                          Icons.threed_rotation_rounded,
                          size: 16,
                        ),
                        label: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _capture,
                      icon: const Icon(Icons.camera_alt_rounded, size: 16),
                      label: const Text('Capture'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.zoom_out_map_rounded, size: 16),
                    Expanded(
                      child: Slider(
                        value: _zoom,
                        min: 0.6,
                        max: 2.0,
                        activeColor: AbzioTheme.accentColor,
                        onChanged: _setZoom,
                      ),
                    ),
                    Text(
                      '${(_zoom * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Text(
                  _isFront ? 'Front view active' : 'Back view active',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
