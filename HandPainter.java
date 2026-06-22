class HandPainter extends CustomPainter {
  final List<dynamic> points;
  HandPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paintPoint = Paint()
            ..color = Colors.cyanAccent
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round;

    final paintLine = Paint()
            ..color = Colors.white.withOpacity(0.8)
            ..strokeWidth = 3;

    // Helper function to map normalized AI points to real Screen pixels
    Offset getOffset(int index) {
      // 1. Mirror the X coordinate for the front camera
      // MediaPipe 0.0 is left, but front cam is flipped.
      // We do (1.0 - x) to flip it back.
      double flippedX = 1.0 - points[index].x;

      return Offset(
              flippedX * size.width,
              points[index].y * size.height
      );
    }

    // Draw the skeleton lines
    void drawLine(int start, int end) {
      canvas.drawLine(getOffset(start), getOffset(end), paintLine);
    }

    if (points.length >= 21) {
      // Draw Connections (Bones)
      // Thumb
      drawLine(0, 1); drawLine(1, 2); drawLine(2, 3); drawLine(3, 4);
      // Index
      drawLine(0, 5); drawLine(5, 6); drawLine(6, 7); drawLine(7, 8);
      // Middle
      drawLine(0, 9); drawLine(9, 10); drawLine(10, 11); drawLine(11, 12);
      // Ring
      drawLine(0, 13); drawLine(13, 14); drawLine(14, 15); drawLine(15, 16);
      // Pinky
      drawLine(0, 17); drawLine(17, 18); drawLine(18, 19); drawLine(19, 20);

      // Draw the Joints (Dots)
      for (int i = 0; i < points.length; i++) {
        canvas.drawCircle(getOffset(i), 4, paintPoint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
