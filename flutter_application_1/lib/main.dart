import 'dart:async';

import 'package:device_orientation/device_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class CustomRectangle {
  Rect rect;
  int id;

  CustomRectangle(this.rect, this.id);

  CustomRectangle clone() {
    return CustomRectangle(
        Rect.fromPoints(this.rect.topLeft, this.rect.bottomRight), id);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: RectangleDrawingScreen(),
    );
  }
}

class RectanglePainter extends CustomPainter {
  List<CustomRectangle> rectangles;
  double containerWidth;
  double containerHeight;

  RectanglePainter(this.rectangles, this.containerWidth, this.containerHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var rect in rectangles) {
      final scaledRect = Rect.fromLTRB(
        rect.rect.left * containerWidth,
        rect.rect.top * containerHeight,
        rect.rect.right * containerWidth,
        rect.rect.bottom * containerHeight,
      );
      canvas.drawRect(scaledRect, paint);
    }
  }

  @override
  bool shouldRepaint(RectanglePainter oldDelegate) {
    return oldDelegate.rectangles != rectangles;
  }
}

class TestWidgetDrawer extends StatefulWidget {
  final double containerWidth;
  final double containerHeight;
  final List<CustomRectangle> initialRectangles;

  final Function(List<CustomRectangle>) onComplete;
  final VoidCallback onCancel;
  TestWidgetDrawer({
    required this.containerHeight,
    required this.containerWidth,
    required this.onComplete,
    required this.onCancel,
    required this.initialRectangles,
  }) : super();

  @override
  State<TestWidgetDrawer> createState() => _TestWidgetDrawerState();
}

class _TestWidgetDrawerState extends State<TestWidgetDrawer> {
  Offset? startPoint;
  Offset? endPoint;
  Offset? dragOffset;
  late CustomRectangle? currentRect;

  late List<CustomRectangle> rectangles;

  bool isDragging = false;
  int nextId = 0;

  @override
  void initState() {
    super.initState();
    currentRect = null;
    rectangles = widget.initialRectangles.map((e) => e.clone()).toList();
  }

  void _onPanStart(DragStartDetails details) {
    var touchToPercentage = _offsetToPercentage(
        details.localPosition, widget.containerWidth, widget.containerHeight);

    for (var rect in rectangles) {
      if (rect.rect.contains(touchToPercentage)) {
        setState(() {
          isDragging = true;
          dragOffset = touchToPercentage - rect.rect.topLeft;
          currentRect = rect;
        });
        return;
      }
    }

    setState(() {
      isDragging = false;
      startPoint = touchToPercentage;
      endPoint = touchToPercentage;
      currentRect =
          CustomRectangle(Rect.fromPoints(startPoint!, endPoint!), nextId++);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (isDragging) {
      var recWidth = currentRect!.rect.width;
      var recWidthAbsolute = recWidth * widget.containerWidth;

      var recHeight = currentRect!.rect.height;
      var recHeightAbsolute = recHeight * widget.containerHeight;

      setState(() {
        final newPosition = _offsetToPercentage(details.localPosition,
                widget.containerWidth, widget.containerHeight) -
            dragOffset!;
        var maxWidthPercentage =
            (widget.containerWidth - recWidthAbsolute) / widget.containerWidth;
        var maxHeightPercentage = (widget.containerHeight - recHeightAbsolute) /
            widget.containerHeight;

        final left = newPosition.dx.clamp(0.0, maxWidthPercentage);
        final top = newPosition.dy.clamp(0.0, maxHeightPercentage);
        final right = left + recWidth;
        final bottom = top + recHeight;

        currentRect!.rect = Rect.fromLTRB(left, top, right, bottom);
      });
    } else {
      setState(() {
        endPoint = _offsetToPercentage(details.localPosition,
            widget.containerWidth, widget.containerHeight);
        currentRect!.rect = Rect.fromPoints(startPoint!, endPoint!);
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!isDragging) {
      setState(() {
        rectangles.add(currentRect!);
      });
    }
    setState(() {
      isDragging = false;
      startPoint = null;
      endPoint = null;
      currentRect = null;
    });
  }

  Offset _offsetToPercentage(Offset offset, double width, double height) {
    return Offset(offset.dx / width, offset.dy / height);
  }

  @override
  Widget build(BuildContext context) {
    var rectanglesToShow = [...rectangles];
    if (currentRect != null) {
      rectanglesToShow.add(currentRect!);
    }

    return Stack(
      children: [
        Positioned(
          top: (ui.window.viewPadding.top / ui.window.devicePixelRatio),
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (rectangles.isNotEmpty) {
                      rectangles.removeLast();
                    }
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(20),
                  child: Icon(
                    Icons.undo,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onCancel.call();
                  },
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "Highlight mode",
                  style: TextStyle(color: Colors.white),
                ),
                TextButton(
                  onPressed: () {
                    widget.onComplete.call(rectangles);
                  },
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        RotatedBox(
          quarterTurns: 4 - deviceOrientation.index,
          child: Center(
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: SizedBox(
                width: widget.containerWidth,
                height: widget.containerHeight,
                child: CustomPaint(
                  painter: RectanglePainter(rectanglesToShow,
                      widget.containerWidth, widget.containerHeight),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RectangleDrawingScreen extends StatefulWidget {
  @override
  _RectangleDrawingScreenState createState() => _RectangleDrawingScreenState();
}

class _RectangleDrawingScreenState extends State<RectangleDrawingScreen> {
  StreamSubscription<DeviceOrientation>? orientationSubscription;

  late double _containerWidth;
  late double _containerHeight;

  var inEditMode = false;

  late List<CustomRectangle> rectangles;

  @override
  void initState() {
    super.initState();

    orientationSubscription = deviceOrientation$.listen((orientation) {
      deviceOrientation = orientation;
      if (mounted) setState(() {});
    });

    rectangles = [CustomRectangle(Rect.fromLTRB(0.1, 0.1, 0.4, 0.4), 1)];
  }

  @override
  void dispose() {
    orientationSubscription?.cancel();
    super.dispose();
  }

  double _getQuarterTurns() {
    return _getTurnsForOrientation(deviceOrientation);
  }

  double _getTurnsForOrientation(DeviceOrientation orientation) {
    Map<DeviceOrientation, double> turns = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeRight: 0.25,
      DeviceOrientation.portraitDown: 0.5,
      DeviceOrientation.landscapeLeft: -0.25,
    };
    return turns[orientation]!;
  }

  List<Widget> getButtons() {
    var buttons = [
      AnimatedRotation(
        turns: _getQuarterTurns(),
        duration: Duration(milliseconds: 0),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // widget.takePictureBloc.add(TakePictureDeclinePictureEvent());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: Size(60, 60),
            padding: EdgeInsets.all(0),
            shape: CircleBorder(),
          ),
          child: const Icon(Icons.close, color: Colors.black),
        ),
      ),
      AnimatedRotation(
        turns: _getQuarterTurns(),
        duration: Duration(milliseconds: 0),
        child: ElevatedButton(
          onPressed: () {
            // if (buttonEnabled) {
            //   //Depending on the speed of the device, confirming the picture can take a while when it's
            //   //the last picture in a series. We just lock the button after the first press
            //   buttonEnabled = false;
            //   widget.takePictureBloc.add(TakePictureConfirmPictureEvent());
            // }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: Size(60, 60),
            padding: EdgeInsets.all(0),
            shape: CircleBorder(),
          ),
          child: const Icon(Icons.check, color: Colors.black),
        ),
      ),
    ];
    if (deviceOrientation == DeviceOrientation.landscapeRight)
      buttons = buttons.reversed.toList();
    return buttons;
  }

  Widget _renderEditButton() {
    return Positioned(
      top: View.of(context).viewPadding.top / View.of(context).devicePixelRatio,
      right: 0,
      child: Container(
        padding: EdgeInsets.all(20),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.0),
            ),
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
            backgroundColor: Colors.grey.shade900,
          ),
          onPressed: () {
            setState(() {
              inEditMode = true;
            });
          },
          child: Row(
            children: [
              Icon(Icons.brush),
              Container(
                padding: EdgeInsets.only(left: 12),
                child: Text(
                  "Edit",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    late double containerWidth;
    late double containerHeight;

    if (deviceOrientation == DeviceOrientation.portraitDown ||
        deviceOrientation == DeviceOrientation.portraitUp) {
      containerWidth = MediaQuery.of(context).size.width;
      containerHeight = containerWidth / 4 * 3;
    } else {
      containerHeight = MediaQuery.of(context).size.width;
      containerWidth = containerHeight / 3 * 4;
    }

    _containerWidth = containerWidth;
    _containerHeight = containerHeight;

    return Material(
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            if (!inEditMode) ...[
              _renderEditButton(),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: getButtons(),
                  ),
                ),
              ),
            ],
            Stack(
              children: [
                RotatedBox(
                  quarterTurns: 4 - deviceOrientation.index,
                  child: Center(
                    child: Image.network(
                      "https://images.unsplash.com/photo-1566475955255-404134a79aeb?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1548&q=80",
                    ),
                  ),
                ),
                if (inEditMode)
                  TestWidgetDrawer(
                    containerHeight: _containerHeight,
                    containerWidth: _containerWidth,
                    initialRectangles: rectangles,
                    onCancel: () {
                      setState(() {
                        inEditMode = false;
                      });
                    },
                    onComplete: (rects) {
                      setState(() {
                        rectangles = rects;
                        inEditMode = false;
                      });
                    },
                  ),

                if (!inEditMode)
                  RotatedBox(
                    quarterTurns: 4 - deviceOrientation.index,
                    child: Center(
                      child: SizedBox(
                        width: _containerWidth,
                        height: _containerHeight,
                        child: CustomPaint(
                          painter: RectanglePainter(
                              rectangles, containerWidth, containerHeight),
                        ),
                      ),
                    ),
                  ),
                // GestureDetector(
                //   onPanStart: _onPanStart,
                //   onPanUpdate: _onPanUpdate,
                //   onPanEnd: _onPanEnd,
                //   child: SizedBox(
                //     width: _containerWidth,
                //     height: _containerHeight,
                //     child: CustomPaint(
                //       painter: RectanglePainter(rectanglesToShow,
                //           _containerWidth, _containerHeight),
                //     ),
                //   ),
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
