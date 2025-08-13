import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MaterialApp(home: LandDrawingMapPage()));
}

class LandDrawingMapPage extends StatefulWidget {
  @override
  _LandDrawingMapPageState createState() => _LandDrawingMapPageState();
}

class _LandDrawingMapPageState extends State<LandDrawingMapPage> {
  GoogleMapController? mapController;
  LatLng? currentPosition;
  List<Offset> points = [];
  bool drawingEnabled = false;

  double totalAreaUnits = 1000;
  List<String> owners = []; // start empty
  List<double> ratios = []; // start empty

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ratioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      currentPosition = LatLng(position.latitude, position.longitude);
    });
    mapController?.moveCamera(CameraUpdate.newLatLngZoom(currentPosition!, 16));
  }

  Future<void> _searchLocation(String query) async {
    if (mapController == null) return;
    if (query.trim().isEmpty) return;

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json');

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FlutterApp',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          mapController!.moveCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lon), 16),
          );
        }
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  void _addOwner() {
    String name = _nameController.text.trim();
    double? ratio = double.tryParse(_ratioController.text.trim());

    if (name.isNotEmpty && ratio != null && ratio > 0) {
      setState(() {
        owners.add(name);
        ratios.add(ratio);
      });
      _nameController.clear();
      _ratioController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          currentPosition == null
              ? Center(child: CircularProgressIndicator())
              : GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: currentPosition!,
                    zoom: 16,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomGesturesEnabled: !drawingEnabled,
                  scrollGesturesEnabled: !drawingEnabled,
                  tiltGesturesEnabled: !drawingEnabled,
                  rotateGesturesEnabled: !drawingEnabled,
                  onMapCreated: (controller) => mapController = controller,
                ),

          if (drawingEnabled)
            GestureDetector(
              onPanStart: (details) {
                setState(() {
                  points.add(details.localPosition);
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  points.add(details.localPosition);
                });
              },
              child: CustomPaint(
                painter: LandPainter(points, owners, ratios, totalAreaUnits),
                child: Container(),
              ),
            ),

          // Search bar
          Positioned(
            top: 40,
            left: 15,
            right: 15,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search location...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
                onSubmitted: _searchLocation,
              ),
            ),
          ),

          // Input fields for owner and ratio
          Positioned(
            bottom: 100,
            left: 15,
            right: 15,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Owner Name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _ratioController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Ratio',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addOwner,
                  child: Text('Add'),
                ),
              ],
            ),
          ),

          // Bottom buttons
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: "locate",
                  child: Icon(Icons.my_location),
                  onPressed: _determinePosition,
                ),
                SizedBox(width: 20),
                FloatingActionButton(
                  heroTag: "draw",
                  child: Icon(drawingEnabled ? Icons.close : Icons.edit),
                  onPressed: () {
                    setState(() {
                      drawingEnabled = !drawingEnabled;
                      if (!drawingEnabled) points.clear();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LandPainter extends CustomPainter {
  final List<Offset> points;
  final List<String> owners;
  final List<double> ratios;
  final double totalArea;

  LandPainter(this.points, this.owners, this.ratios, this.totalArea);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || owners.isEmpty || ratios.isEmpty) return;

    final paintLine = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (points.length > 1) {
      Path path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length - 1; i++) {
        final mid = (points[i] + points[i + 1]) / 2;
        path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(points.last.dx, points.last.dy);
      if (points.length > 2) path.close();
      canvas.drawPath(path, paintLine);

      double minY = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      double maxY = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
      double height = maxY - minY;

      List<Color> colors = [
        Colors.red,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.yellow
      ];
      double currentY = minY;

      for (int i = 0; i < owners.length; i++) {
        double sectionHeight = height * ratios[i];

        canvas.drawPath(
          Path.combine(
            PathOperation.intersect,
            path,
            Path()
              ..addRect(Rect.fromLTRB(
                  0, currentY, size.width, currentY + sectionHeight)),
          ),
          Paint()
            ..color = colors[i % colors.length].withOpacity(0.5)
            ..style = PaintingStyle.fill,
        );

        double landValue = ratios[i] * totalArea;
        String label =
            "${owners[i]}\n${(ratios[i] * 100).toStringAsFixed(1)}%\n${landValue.toStringAsFixed(2)} units";

        TextPainter tp = TextPainter(
          text: TextSpan(
              style: TextStyle(color: Colors.black, fontSize: 12), text: label),
          textAlign: TextAlign.center,
          textDirection: ui.TextDirection.ltr,
        );
        tp.layout();

        double labelX = size.width / 2 - tp.width / 2;
        double labelY = currentY + sectionHeight / 2 - tp.height / 2;
        tp.paint(canvas, Offset(labelX, labelY));

        currentY += sectionHeight;
      }

      Paint pointPaint = Paint()..color = Colors.blue;
      for (var point in points) {
        canvas.drawCircle(point, 6, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
