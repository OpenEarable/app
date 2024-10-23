import 'package:flutter/material.dart';

/// Creates a grid that tries to keep the children as square as possible
class SquareChildrenGrid extends StatelessWidget {
  final List<Widget> children;

  const SquareChildrenGrid({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int childrenCount = children.length;
        double aspectRatio = constraints.maxWidth / constraints.maxHeight;

        // Define a number of columns and rows to get an aspect ration close to
        // the available space
        double childrenAspectRation = double.maxFinite;
        int rows = 1;
        int cols = childrenCount;
        for (int newRows = 1; newRows <= childrenCount; ++newRows) {
          int newCols = (childrenCount / newRows).ceil();
          double newChildrenAspectRation = newCols / newRows;

          // Check if the difference between widget size aspect ration
          // and rows to columns ratio decreased
          if ((newChildrenAspectRation - aspectRatio).abs() <
              (childrenAspectRation - aspectRatio).abs()) {
            childrenAspectRation = newChildrenAspectRation;
            cols = newCols;
            rows = newRows;
          } else {
            break;
          }
        }

        // Remove empty rows
        bool changes = true;
        while (changes) {
          int emptyCells = rows * cols - childrenCount;
          if (emptyCells >= cols && rows > 1) {
            --rows;
            emptyCells -= cols;
            continue;
          }
          changes = false;
        }

        return Column(
          children: [
            for (int row = 0; row < rows; ++row)
              Expanded(
                child: Row(
                  children: [
                    for (int column = 0; column < cols; ++column)
                      Expanded(
                        child: (row * cols + column) < childrenCount
                            ? children[row * cols + column]
                            : SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
